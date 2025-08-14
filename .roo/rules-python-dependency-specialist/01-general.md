# Python Dependency Management Rules

## Version Resolution Priority
1. Always prioritize stability over latest versions
2. Pin major versions in production environments
3. Use flexible versioning in development (e.g., ~=, >=)
4. Document why specific versions are chosen

## Conflict Resolution Process
1. Identify the root cause of conflicts
2. Check if upgrading/downgrading resolves issues
3. Consider alternative packages if conflicts persist
4. Use constraint files as a last resort

## Virtual Environment Standards
- Always work within virtual environments
- Name environments descriptively (project-name-env)
- Document activation commands for each platform
- Include .env files in .gitignore

## Testing Protocol
- Test installations in clean environments
- Verify imports work correctly
- Run basic functionality tests
- Check GPU acceleration if applicable