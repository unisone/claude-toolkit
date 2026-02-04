# CI/CD Integration Examples

## GitHub Actions

### Basic Quality Gate

```yaml
name: Code Quality
on: [pull_request]

jobs:
  techdebt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npx @unisone/claude-toolkit techdebt --threshold high
```

### Advanced with JSON Output

```yaml
name: Code Quality Report
on: [push, pull_request]

jobs:
  techdebt-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run techdebt scan
        id: scan
        run: |
          npx @unisone/claude-toolkit techdebt --json > report.json
          cat report.json
        continue-on-error: true
      
      - name: Parse and comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('report.json', 'utf8'));
            
            const body = `## 📊 Techdebt Scan Results
            
            - **Critical**: ${report.summary.critical}
            - **High**: ${report.summary.high}
            - **Medium**: ${report.summary.medium}
            - **Low**: ${report.summary.low}
            - **Total**: ${report.summary.total}
            
            ${report.summary.critical > 0 ? '❌ Critical issues must be fixed before merge' : '✅ No critical issues'}
            `;
            
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
      
      - name: Fail on critical issues
        run: |
          CRITICAL=$(jq -r '.summary.critical' report.json)
          if [ "$CRITICAL" -gt 0 ]; then
            echo "Critical issues found!"
            exit 1
          fi
      
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: techdebt-report
          path: report.json
```

### Scheduled Scans

```yaml
name: Weekly Techdebt Audit
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Full scan with duplicates
        run: |
          npx @unisone/claude-toolkit techdebt --duplicates --json > weekly-audit.json
      
      - name: Create issue if critical debt found
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('weekly-audit.json', 'utf8'));
            
            if (report.summary.critical > 0 || report.summary.high > 5) {
              github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: `⚠️ Techdebt Alert: ${report.summary.critical} critical, ${report.summary.high} high priority`,
                body: `Automated weekly scan detected concerning technical debt:\n\n\`\`\`json\n${JSON.stringify(report.summary, null, 2)}\n\`\`\`\n\nRun \`npx @unisone/claude-toolkit techdebt\` locally for details.`,
                labels: ['techdebt', 'automated']
              });
            }
```

## GitLab CI

```yaml
techdebt:
  stage: test
  image: node:18
  script:
    - npx @unisone/claude-toolkit techdebt --json > report.json
    - cat report.json
  artifacts:
    reports:
      junit: report.json
    paths:
      - report.json
    expire_in: 1 week
  allow_failure: false
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

## CircleCI

```yaml
version: 2.1

jobs:
  techdebt:
    docker:
      - image: node:18
    steps:
      - checkout
      - run:
          name: Run techdebt scan
          command: npx @unisone/claude-toolkit techdebt --threshold high
      - run:
          name: Generate report
          command: npx @unisone/claude-toolkit techdebt --json > /tmp/report.json
          when: always
      - store_artifacts:
          path: /tmp/report.json

workflows:
  quality-check:
    jobs:
      - techdebt
```

## Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
echo "Running techdebt scan..."

npx @unisone/claude-toolkit techdebt --threshold high --summary

if [ $? -eq 1 ]; then
  echo "❌ Critical issues detected. Commit blocked."
  echo "Run: npx @unisone/claude-toolkit techdebt --fix"
  exit 1
fi

exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

## Husky Integration

Install husky:

```bash
npm install --save-dev husky
npx husky init
```

Add to `.husky/pre-commit`:

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx @unisone/claude-toolkit techdebt --threshold high --summary || exit 1
```

## Make Target

Add to `Makefile`:

```makefile
.PHONY: quality-check
quality-check:
	@echo "Running techdebt scan..."
	@npx @unisone/claude-toolkit techdebt --threshold high

.PHONY: quality-report
quality-report:
	@npx @unisone/claude-toolkit techdebt --json > techdebt-report.json
	@cat techdebt-report.json

.PHONY: fix-quality
fix-quality:
	@npx @unisone/claude-toolkit techdebt --fix
```

Then use:

```bash
make quality-check    # Run scan
make quality-report   # Generate JSON report
make fix-quality      # Auto-fix issues
```
