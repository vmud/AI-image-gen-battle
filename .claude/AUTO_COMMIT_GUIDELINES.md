# Claude Auto-Commit Guidelines

## When Claude Will Automatically Commit

### ✅ Automatic Commit Triggers

1. **Completed Feature** - When a feature is fully implemented and tested
   - ✓ All functionality working
   - ✓ Error handling in place
   - ✓ Documentation updated if needed

2. **Fixed Bug** - When a bug is identified and resolved
   - ✓ Root cause identified
   - ✓ Fix implemented and tested
   - ✓ No regression introduced

3. **Refactored Code** - When code is improved without changing functionality
   - ✓ Code is cleaner/more maintainable
   - ✓ Performance improved
   - ✓ Functionality preserved

4. **Added Documentation** - When significant documentation is created/updated
   - ✓ README updates
   - ✓ API documentation
   - ✓ Setup guides
   - ✓ Architecture documents

5. **Configuration Change** - When system configuration is updated
   - ✓ Deployment scripts
   - ✓ Environment settings
   - ✓ Build configurations
   - ✓ CI/CD updates

6. **Deployment Update** - When deployment-related files are modified
   - ✓ Docker files
   - ✓ Infrastructure as code
   - ✓ Release preparations

### 🚫 When Claude Will NOT Auto-Commit

- Work in progress / incomplete features
- Experimental code that might be reverted
- Temporary debugging changes
- Configuration files with sensitive data
- Files matching exclusion patterns (*.log, *.tmp, etc.)
- Changes affecting fewer than 5 lines (configurable)
- More than 10 files changed at once (requires manual review)

## GitHub Push Recommendations

### 🔄 When Claude Will Recommend Pushing

1. **Major Feature Complete**
   - Significant functionality fully implemented
   - Multiple related commits ready
   - Feature is stable and tested

2. **Deployment Ready**
   - All deployment scripts updated
   - Configuration verified
   - Ready for production deployment

3. **Multiple Commits Ready**
   - 3+ related commits accumulated
   - Logical grouping of changes
   - No pending work that would conflict

4. **End of Work Session**
   - Natural stopping point reached
   - All current work is stable
   - Good time to backup progress

### ⚠️ Push Safety Checks

Before recommending a push, Claude will verify:
- ✅ No uncommitted changes remain
- ✅ All tests pass (if test commands available)
- ✅ No secrets or sensitive data in changes
- ✅ Commit messages are descriptive
- ✅ Changes are logically grouped

### 🎯 Push Timing Strategy

**Immediate Push Recommended:**
- Critical bug fixes
- Security updates
- Deployment-blocking issues

**Batch Push Recommended:**
- Feature development chunks
- Documentation updates
- Configuration changes
- Refactoring improvements

**Hold for Confirmation:**
- Major architectural changes
- Breaking changes
- First-time deployments
- Sensitive configuration updates

## Example Workflow

```
1. User: "Fix the DirectML installation error"
   → Claude fixes bug
   → Auto-commits: "Fix DirectML installation compatibility issue"

2. User: "Add documentation for the setup process"
   → Claude creates docs
   → Auto-commits: "Add comprehensive setup documentation"

3. User: "Optimize the image generation pipeline"
   → Claude implements optimization
   → Auto-commits: "Optimize image generation with caching and batch processing"
   
4. After 3+ commits accumulated:
   → Claude recommends: "Ready to push deployment improvements to GitHub?"
```

## Override Commands

**Force Commit (bypasses auto-rules):**
- "commit these changes now"
- "commit and push"

**Skip Auto-Commit:**
- "don't commit yet"
- "save as work in progress"

**Force Push:**
- "push to github now"
- "deploy changes immediately"

## Configuration Customization

Edit `.claude/settings.local.json` to adjust:
- `minimumChangeThreshold`: Minimum lines changed for auto-commit
- `maxFilesPerCommit`: Maximum files to include in one commit
- `triggerConditions`: Add/remove auto-commit scenarios
- `excludeFiles`: Patterns for files to never auto-commit

## Benefits

✅ **Consistent Git History** - Regular, well-documented commits
✅ **Reduced Manual Overhead** - No need to remember to commit
✅ **Better Backup Strategy** - Frequent snapshots of progress
✅ **Improved Collaboration** - Clear change tracking
✅ **Deployment Safety** - Controlled push timing
✅ **Work Continuity** - Easy to resume from any point

---

*This system balances automation with safety, ensuring code is regularly committed while maintaining control over when changes are shared publicly.*