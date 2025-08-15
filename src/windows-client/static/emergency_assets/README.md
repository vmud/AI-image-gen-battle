# Emergency Assets Directory

This directory contains prebuilt images used by the emergency simulation mode when actual AI generation is unavailable.

## Directory Purpose

Emergency mode provides realistic demonstration capabilities without requiring:
- GPU/NPU acceleration
- AI model downloads
- Network connectivity
- Large memory allocation

## Image Storage Structure

### File Naming Convention
```
emergency_{category}_{variant}_{platform}.png
```

**Parameters:**
- `category`: Image category (landscape, portrait, abstract, etc.)
- `variant`: Numeric variant (0, 1, 2) for variety within categories
- `platform`: Target platform (snapdragon, intel)

### Example Files
```
emergency_landscape_0_snapdragon.png
emergency_landscape_1_snapdragon.png
emergency_landscape_2_snapdragon.png
emergency_portrait_0_snapdragon.png
emergency_abstract_0_snapdragon.png
emergency_technology_0_snapdragon.png
...
```

## Supported Categories

The emergency simulator recognizes these prompt categories:

| Category | Keywords | Description |
|----------|----------|-------------|
| **landscape** | landscape, mountain, ocean, forest, nature, scenic, valley, sunset, sunrise | Natural outdoor scenes |
| **portrait** | person, face, human, portrait, character, man, woman, child | People and character images |
| **abstract** | abstract, pattern, geometric, colorful, artistic, modern | Abstract art and patterns |
| **architecture** | building, house, city, urban, structure, architecture, cityscape | Buildings and urban scenes |
| **fantasy** | dragon, magic, fantasy, mythical, unicorn, castle, fairy | Fantasy and mythical content |
| **technology** | robot, futuristic, sci-fi, cyberpunk, tech, computer, ai | Technology and sci-fi |
| **animals** | cat, dog, bird, animal, wildlife, pet, horse, elephant | Animals and wildlife |
| **vehicles** | car, truck, plane, ship, vehicle, motorcycle, train | Transportation |
| **food** | food, meal, cooking, restaurant, kitchen, delicious | Food and cooking |
| **space** | space, planet, star, galaxy, astronaut, cosmos, universe | Space and astronomy |

## Image Specifications

### Technical Requirements
- **Format:** PNG
- **Resolution:** 768×768 pixels
- **Color Depth:** 24-bit RGB
- **File Size:** Recommended < 500KB each

### Platform-Specific Branding
**Snapdragon Images:**
- Color scheme: Red/orange gradients (#c41e3a, #ff6b6b, #ffa500)
- Branding: "Snapdragon X Elite" text overlay
- Style: Modern, performance-focused

**Intel Images:**
- Color scheme: Blue/orange gradients (#0071c5, #4a90e2, #ffa500) 
- Branding: "Intel Core Ultra" text overlay
- Style: Professional, technical

## Auto-Generation

If prebuilt images are missing, the emergency simulator will automatically generate placeholder images with:
- Platform-appropriate color schemes
- Category-specific visual elements (mountains for landscape, geometric shapes for abstract, etc.)
- Platform branding overlays
- Fallback patterns for unsupported categories

## Image Selection Algorithm

1. **Prompt Analysis:** Categorize user prompt based on keyword matching
2. **Hash-Based Selection:** Use MD5 hash of prompt to consistently select same variant
3. **Platform Filtering:** Choose platform-specific version (snapdragon/intel)
4. **Fallback Chain:** 
   - Specific category + variant + platform
   - Category + variant 0 + platform  
   - Abstract + variant 0 + platform
   - Auto-generated placeholder

## Performance Impact

**Storage Requirements:**
- 10 categories × 3 variants × 2 platforms = 60 images maximum
- ~30MB total storage (at 500KB per image)

**Load Times:**
- Images loaded on-demand during generation
- Cached in memory for subsequent use
- No impact on startup time

## Customization

### Adding Custom Images
1. Follow naming convention: `emergency_{category}_{variant}_{platform}.png`
2. Use 768×768 PNG format
3. Include platform branding for consistency
4. Place in this directory

### Adding New Categories
1. Update prompt categories in `emergency_simulator.py`
2. Create corresponding image files for both platforms
3. Add category-specific visual elements in `add_category_elements()`

### Platform Variations
Create separate image sets for each platform to maintain branding consistency and optimize for platform-specific performance characteristics.

## Deployment Notes

- This directory is automatically created by `snapdragon_launch.bat`
- Images are generated on first use if missing
- Safe to delete - images will be regenerated as needed
- Version control: Consider `.gitignore` for large image files

## Quality Guidelines

For best demo experience:
- Use high-quality source images
- Maintain consistent visual style within categories
- Include platform branding for authenticity
- Test image loading in emergency mode before deployment

---

**Location:** `src/windows-client/static/emergency_assets/`  
**Auto-created by:** [`emergency_simulator.py`](../emergency_simulator.py) and [`snapdragon_launch.bat`](../../../snapdragon_launch.bat)  
**Used by:** Emergency simulation mode for realistic demo performance