import importlib.util
import os
import sys
import types
from types import SimpleNamespace
from pathlib import Path
import tempfile
import shutil
import pytest


class FakeDirectML(types.ModuleType):
    def __init__(self, available=True):
        super().__init__("torch_directml")
        self._available = available

    def is_available(self):
        return self._available

    def device(self):
        return "directml:0"

    def device_name(self, idx):
        return "Intel Arc (Fake)"


class FakeScheduler:
    def __init__(self):
        self.config = {"dummy": True}


class FakeDPMSolver(types.ModuleType):
    def __init__(self):
        super().__init__("DPMSolverMultistepScheduler")

    @staticmethod
    def from_config(config, **kwargs):
        return FakeScheduler()


class FakeStableDiffusionPipeline:
    def __init__(self):
        self.scheduler = FakeScheduler()
        self.to_called = False
        self.enable_attention_slicing_called = False
        self.enable_vae_slicing_called = False
        self.enable_model_cpu_offload_called = False
        self.last_kwargs = None

    @classmethod
    def from_pretrained(cls, *args, **kwargs):
        return cls()

    def to(self, device):
        self.to_called = True
        return self

    def enable_attention_slicing(self, *args, **kwargs):
        self.enable_attention_slicing_called = True

    def enable_vae_slicing(self, *args, **kwargs):
        self.enable_vae_slicing_called = True

    def enable_model_cpu_offload(self, *args, **kwargs):
        self.enable_model_cpu_offload_called = True

    def __call__(self, **kwargs):
        # Capture the kwargs to assert on them in tests
        self.last_kwargs = kwargs
        return SimpleNamespace(images=[object()])


class FakeDiffusers(types.ModuleType):
    def __init__(self):
        super().__init__("diffusers")
        # Expose the classes as attributes to match "from diffusers import ..."
        self.StableDiffusionXLPipeline = FakeStableDiffusionPipeline
        self.DPMSolverMultistepScheduler = FakeDPMSolver()


class FakeORTSDXLPipeline:
    def __init__(self):
        self.scheduler = SimpleNamespace(config=SimpleNamespace(num_train_timesteps=0))
        self.vae_scale_factor = 0
        self.enable_attention_slicing_called = False
        self.last_kwargs = None

    @classmethod
    def from_pretrained(cls, *args, **kwargs):
        return cls()

    def enable_attention_slicing(self, *args, **kwargs):
        self.enable_attention_slicing_called = True

    def __call__(self, **kwargs):
        self.last_kwargs = kwargs
        return SimpleNamespace(images=[object()])


class FakeOptimumOnnxRuntime(types.ModuleType):
    def __init__(self):
        super().__init__("optimum.onnxruntime")
        self.ORTStableDiffusionXLPipeline = FakeORTSDXLPipeline


class FakeOnnxRuntime(types.ModuleType):
    def __init__(self):
        super().__init__("onnxruntime")
        self.GraphOptimizationLevel = SimpleNamespace(ORT_ENABLE_ALL=1)

    class SessionOptions:
        def __init__(self):
            self.graph_optimization_level = None


class FakePsutil(types.ModuleType):
    def __init__(self):
        super().__init__("psutil")

    class _MemInfo:
        def __init__(self, rss):
            self.rss = rss

    class _Process:
        def memory_info(self):
            # 500 MB baseline
            return FakePsutil._MemInfo(500 * 1024 * 1024)

    def Process(self):
        return FakePsutil._Process()

    def cpu_percent(self, interval=0.1):
        return 20.0

    class _VirtMem:
        def __init__(self):
            self.percent = 40.0

    def virtual_memory(self):
        return FakePsutil._VirtMem()


class FakeHFHub(types.ModuleType):
    def __init__(self, recorder):
        super().__init__("huggingface_hub")
        self._recorder = recorder

    def snapshot_download(self, **kwargs):
        self._recorder.append(kwargs)


class FakeTorch(types.ModuleType):
    def __init__(self):
        super().__init__("torch")
        # Dtype placeholders
        self.float16 = "float16"
        self.float32 = "float32"

    class Generator:
        def manual_seed(self, seed):
            return self


def load_ai_pipeline_module_with_fakes(fakes: dict):
    """
    Dynamically load ai_pipeline.py with sys.modules patched to include fake heavy dependencies.
    Returns the loaded module object.
    """
    # Patch sys.modules with fakes
    for name, mod in fakes.items():
        sys.modules[name] = mod

    spec = importlib.util.spec_from_file_location(
        "ai_pipeline_mod",
        str(Path("src/windows-client/ai_pipeline.py"))
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load spec for ai_pipeline.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_default_fakes(directml_available=True, hf_recorder=None):
    # Create parent "optimum" package and its "onnxruntime" submodule
    optimum_pkg = types.ModuleType("optimum")
    optimum_onnxruntime = FakeOptimumOnnxRuntime()
    return {
        "torch": FakeTorch(),
        "torch_directml": FakeDirectML(available=directml_available),
        "diffusers": FakeDiffusers(),
        "onnxruntime": FakeOnnxRuntime(),
        "optimum": optimum_pkg,
        "optimum.onnxruntime": optimum_onnxruntime,
        "psutil": FakePsutil(),
        "huggingface_hub": FakeHFHub(hf_recorder if hf_recorder is not None else []),
    }


def test_intel_setup_happy_path():
    fakes = make_default_fakes(directml_available=True)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        assert gen.optimization_backend == "directml"
        assert gen.pipeline is not None
        assert gen.model_loaded is True
        # Env hints are set
        assert os.environ.get("ORT_DIRECTML_DEVICE_ID") == "0"
        assert os.environ.get("MKL_ENABLE_INSTRUCTIONS") == "AVX512"
    finally:
        shutil.rmtree(tmp)


def test_intel_setup_fallback_cpu_when_no_directml():
    fakes = make_default_fakes(directml_available=False)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        assert gen.optimization_backend == "cpu"
        assert gen.device == "cpu"
        assert gen.pipeline is not None
    finally:
        shutil.rmtree(tmp)


def test_generate_image_cpu_passes_output_type_and_return_dict():
    fakes = make_default_fakes(directml_available=False)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        # Ensure CPU path
        assert gen.optimization_backend == "cpu"
        # Use fake pipeline already present
        result_image, metrics = gen.generate_image(prompt="test prompt", steps=3, resolution=(64, 64))
        # Assert the pipeline received expected kwargs
        assert gen.pipeline.last_kwargs["output_type"] == "pil"
        assert gen.pipeline.last_kwargs["return_dict"] is True
        assert result_image is not None
        # Basic metrics keys
        for key in ("generation_time", "ms_per_step", "steps_per_second", "memory_used_mb"):
            assert key in metrics
        # Platform-specific utilization not added for Snapdragon, but for Intel (cpu fallback) it is added
        assert "directml_active" in metrics
    finally:
        shutil.rmtree(tmp)


def test_generate_image_directml_passes_output_type_pil():
    fakes = make_default_fakes(directml_available=True)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        assert gen.optimization_backend == "directml"
        img, metrics = gen.generate_image(prompt="hello", steps=2, resolution=(64, 64))
        assert gen.pipeline.last_kwargs["output_type"] == "pil"
        assert img is not None
        assert metrics["backend"] == "directml"
    finally:
        shutil.rmtree(tmp)


def test_snapdragon_optimized_generation_path():
    fakes = make_default_fakes(directml_available=False)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        # Create the "optimized" model folder to trigger Snapdragon optimized path
        (tmp / "sdxl_snapdragon_optimized").mkdir(parents=True, exist_ok=True)
        gen = mod.AIImageGenerator(platform_info={"platform_type": "snapdragon"}, model_path=str(tmp))
        assert gen.optimization_backend == "qualcomm_npu"
        img, metrics = gen.generate_image(prompt="qcom", steps=2, resolution=(64, 64))
        # ORT pipeline should have received output_type and return_dict via helper
        assert gen.pipeline.last_kwargs["output_type"] == "pil"
        assert gen.pipeline.last_kwargs["return_dict"] is True
        assert img is not None
        assert metrics["backend"] == "qualcomm_npu"
        # For Snapdragon, Intel-specific metrics should not be added
        assert "directml_active" not in metrics or metrics["directml_active"] is False
    finally:
        shutil.rmtree(tmp)


def test_generate_image_raises_and_propagates_exception():
    fakes = make_default_fakes(directml_available=False)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))

        class BoomPipeline:
            def __call__(self, **kwargs):
                raise RuntimeError("boom")

        # Replace the pipeline with a callable that raises
        gen.pipeline = BoomPipeline()  # type: ignore

        with pytest.raises(RuntimeError, match="boom"):
            gen.generate_image(prompt="err", steps=1, resolution=(32, 32))
    finally:
        shutil.rmtree(tmp)


def test_download_intel_models_calls_snapshot_download():
    recorder = []
    fakes = make_default_fakes(directml_available=False, hf_recorder=recorder)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        gen._download_intel_models(None)
        assert len(recorder) == 1
        call = recorder[0]
        assert call["repo_id"] == "stabilityai/stable-diffusion-xl-base-1.0"
        # Verify local_dir points to sdxl-base-1.0 under model_path
        assert str(call["local_dir"]).endswith("sdxl-base-1.0")
    finally:
        shutil.rmtree(tmp)


def test_analyze_intel_performance_thresholds():
    fakes = make_default_fakes(directml_available=False)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        gen = mod.AIImageGenerator(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        # Excellent
        a1 = gen._analyze_intel_performance(generation_time=30.0, steps=25, memory_used=2000)
        assert a1["performance_rating"] == "Excellent"
        assert a1["meets_target"] is True
        assert "optimization_suggestions" in a1

        # Good
        a2 = gen._analyze_intel_performance(generation_time=45.0, steps=25, memory_used=2000)
        assert a2["performance_rating"] == "Good"
        assert a2["meets_target"] is True

        # Needs Optimization with suggestions (slow and memory high)
        a3 = gen._analyze_intel_performance(generation_time=70.0, steps=20, memory_used=15000)
        assert a3["performance_rating"] == "Needs Optimization"
        assert a3["meets_target"] is False
        assert any("reducing steps" in s.lower() for s in a3["optimization_suggestions"])
        # Step efficiency should be below target at ~0.29 sps
        assert a3["step_efficiency"] == "Below Target"
    finally:
        shutil.rmtree(tmp)


def test_aiimagepipeline_wrapper_generate_returns_image():
    fakes = make_default_fakes(directml_available=False)
    mod = load_ai_pipeline_module_with_fakes(fakes)
    tmp = Path(tempfile.mkdtemp())
    try:
        pipe = mod.AIImagePipeline(platform_info={"platform_type": "intel"}, model_path=str(tmp))
        img = pipe.generate(prompt="wrapper", steps=2, width=64, height=64)
        assert img is not None
    finally:
        shutil.rmtree(tmp)
