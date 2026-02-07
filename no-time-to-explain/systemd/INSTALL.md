# Installing the systemd timer for no-time-to-explain refresh

## Prerequisites

- Docker Compose is installed
- The no-time-to-explain application is deployed at `/mnt/services/no-time-to-explain`
- The compose stack is running (`docker compose up -d`)

## Installation Steps

1. **Symlink the systemd files to the system directory:**

   ```bash
   sudo ln -s /mnt/services/no-time-to-explain/systemd/no-time-to-explain-refresh.service /etc/systemd/system/
   sudo ln -s /mnt/services/no-time-to-explain/systemd/no-time-to-explain-refresh.timer /etc/systemd/system/
   ```

2. **Reload systemd to pick up the new files:**

   ```bash
   sudo systemctl daemon-reload
   ```

3. **Enable and start the timer:**

   ```bash
   sudo systemctl enable no-time-to-explain-refresh.timer
   sudo systemctl start no-time-to-explain-refresh.timer
   ```

## Verification

Check that the timer is active and scheduled:

```bash
systemctl status no-time-to-explain-refresh.timer
```

You should see output showing the timer is active and the next trigger time.

List all timers to see when it will run next:

```bash
systemctl list-timers no-time-to-explain-refresh.timer
```

## Testing

Manually trigger a run to test it works:

```bash
sudo systemctl start no-time-to-explain-refresh.service
```

Check the logs:

```bash
journalctl -u no-time-to-explain-refresh.service -f
```

## Monitoring

View recent runs and their status:

```bash
systemctl status no-time-to-explain-refresh.service
```

Follow the logs in real-time:

```bash
journalctl -u no-time-to-explain-refresh.service -f
```

View logs for the last hour:

```bash
journalctl -u no-time-to-explain-refresh.service --since "1 hour ago"
```

## Stopping/Disabling

To stop the timer:

```bash
sudo systemctl stop no-time-to-explain-refresh.timer
```

To disable it from running on boot:

```bash
sudo systemctl disable no-time-to-explain-refresh.timer
```

## Troubleshooting

If the service fails to run:

1. Check that the Docker Compose stack is running:
   ```bash
   docker compose ps
   ```

2. Verify the working directory in the service file matches your deployment path

3. Test the command manually:
   ```bash
   cd /mnt/services/no-time-to-explain
   docker compose run --rm app no-time-to-explain refresh
   ```

4. Check systemd logs for errors:
   ```bash
   journalctl -xe -u no-time-to-explain-refresh.service
   ```
