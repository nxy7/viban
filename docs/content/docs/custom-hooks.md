---
title: Custom Hooks
description: Build powerful automations with custom hooks in Viban.
---

# Custom Hooks

Build powerful automations with custom hooks. This guide covers advanced hook patterns and real-world examples.

## Hook Types

### Shell Hooks

Run shell commands:

```yaml
on_completed:
  - name: build
    type: shell
    command: npm run build
```

### HTTP Hooks

Make HTTP requests:

```yaml
on_completed:
  - name: webhook
    type: http
    url: https://api.example.com/webhook
    method: POST
    headers:
      Authorization: Bearer $API_TOKEN
    body:
      task_id: $TASK_ID
      status: completed
```

### Script Hooks

Run script files:

```yaml
on_completed:
  - name: deploy
    type: script
    path: .viban/scripts/deploy.sh
```

## Real-World Examples

### CI/CD Integration

Trigger CI pipeline on completion:

```yaml
on_completed:
  - name: trigger-ci
    type: http
    url: https://api.github.com/repos/$REPO/dispatches
    method: POST
    headers:
      Authorization: token $GITHUB_TOKEN
      Accept: application/vnd.github.v3+json
    body:
      event_type: viban-task-complete
      client_payload:
        task_id: $TASK_ID
        branch: $BRANCH_NAME
```

### Slack Notifications

```yaml
on_started:
  - name: notify-start
    type: http
    url: $SLACK_WEBHOOK
    method: POST
    body:
      text: "Started: $TASK_TITLE"

on_completed:
  - name: notify-complete
    type: http
    url: $SLACK_WEBHOOK
    method: POST
    body:
      text: "Completed: $TASK_TITLE"
      attachments:
        - color: good
          fields:
            - title: Branch
              value: $BRANCH_NAME
              short: true
```

### Auto-Deploy Preview

Deploy preview environments:

```yaml
on_completed:
  - name: deploy-preview
    type: shell
    command: |
      vercel deploy --prebuilt \
        --token $VERCEL_TOKEN \
        --scope $VERCEL_SCOPE \
        --meta taskId=$TASK_ID
    working_dir: $WORKTREE_PATH
```

### Run Tests with Coverage

```yaml
on_completed:
  - name: test-coverage
    type: shell
    command: |
      npm run test:coverage
      if [ $? -ne 0 ]; then
        echo "Tests failed!"
        exit 1
      fi

      # Upload coverage
      curl -s https://codecov.io/bash | bash
    working_dir: $WORKTREE_PATH
```

### Security Scanning

```yaml
on_completed:
  - name: security-scan
    type: shell
    command: |
      npm audit --audit-level=high
      if [ $? -ne 0 ]; then
        echo "Security vulnerabilities found!"
        exit 1
      fi
```

## Advanced Patterns

### Conditional Execution

```yaml
on_completed:
  - name: deploy-staging
    type: shell
    command: ./deploy.sh staging
    condition: |
      $BRANCH_NAME =~ ^feature/.*

  - name: deploy-production
    type: shell
    command: ./deploy.sh production
    condition: |
      $BRANCH_NAME == "main"
```

### Error Handling

```yaml
on_completed:
  - name: critical-task
    type: shell
    command: ./critical.sh
    on_failure: abort
    retry:
      attempts: 3
      delay: 5  # seconds

  - name: optional-task
    type: shell
    command: ./optional.sh
    on_failure: continue
```

### Parallel Execution

```yaml
on_completed:
  - name: parallel-tasks
    parallel:
      - name: lint
        command: npm run lint
      - name: test
        command: npm run test
      - name: typecheck
        command: npm run typecheck
```

## Secret Management

### Environment Variables

Reference secrets from environment:

```yaml
on_completed:
  - name: deploy
    type: shell
    command: ./deploy.sh
    env:
      AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
```

### Secret Files

For complex secrets, use files:

```yaml
on_completed:
  - name: deploy
    type: shell
    command: |
      source .viban/secrets.env
      ./deploy.sh
```

**Note**: Never commit secrets to git!

## Testing Hooks

### Local Testing

```bash
# Export test variables
export TASK_ID=test-123
export TASK_TITLE="Test Task"
export WORKTREE_PATH=/tmp/test

# Run hook manually
./.viban/scripts/your-hook.sh
```

### Dry Run

```bash
mix viban.hooks.test --dry-run --event completed
```

This shows what would execute without running it.
