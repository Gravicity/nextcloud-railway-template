# NextCloud with High-Performance Backend - Railway Template

This Railway template provides a complete NextCloud deployment with Talk High-Performance Backend, optimized to resolve common security warnings and performance issues.

## Features

✅ **Resolves Security Warnings:**
- High-Performance Backend for NextCloud Talk configured
- Proper security headers (HSTS, CSP, etc.)
- Optimized PHP configuration
- Database indices automatically added
- Maintenance window configured
- Redis caching and session storage

✅ **Performance Optimizations:**
- OPcache enabled and tuned
- Redis for distributed caching and file locking
- Optimized database configuration
- Background job cron properly configured

✅ **Production Ready:**
- Supervisor for process management
- Automatic database migrations
- Health checks for all services
- Proper logging configuration

## Architecture

The template deploys 4 services:

1. **NextCloud** - Main application with custom optimizations
2. **MariaDB** - Database with performance tuning
3. **Redis** - Caching and session storage
4. **Talk HPB** - High-Performance Backend for video calls

## Quick Deploy

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/your-template-id)

## Files Structure

```
nextcloud-railway-template/
├── railway.json              # Railway template definition
├── railway.toml             # Railway configuration
├── Dockerfile               # Custom NextCloud image
├── php.ini                  # PHP optimizations
├── apache-security.conf     # Security headers
├── supervisord.conf         # Process management
├── entrypoint.sh           # Custom initialization
├── config.php              # NextCloud configuration template
└── README.md               # This file
```

## Manual Setup

If you want to deploy manually:

### 1. Clone and Customize

```bash
git clone https://github.com/your-username/nextcloud-railway-template
cd nextcloud-railway-template
```

### 2. Deploy to Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Deploy the project
railway up
```

### 3. Configure Domains

1. In Railway dashboard, go to your NextCloud service
2. Add your custom domain
3. Update the environment variables if needed:
   - `NEXTCLOUD_TRUSTED_DOMAINS`
   - `OVERWRITEHOST`
   - `OVERWRITECLIURL`

### 4. Initial Setup

1. Access your NextCloud instance
2. Complete the initial setup wizard
3. The Talk app will be automatically installed and configured
4. All security warnings should be resolved automatically

## Post-Deployment Configuration

### Email Setup (Optional)

Add these environment variables to the NextCloud service:

```
MAIL_SMTPHOST=your-smtp-server.com
MAIL_SMTPPORT=587
MAIL_SMTPAUTH=1
MAIL_SMTPNAME=your-email@domain.com
MAIL_SMTPPASSWORD=your-app-password
```

### Custom Domain for Talk HPB

For optimal performance, you can set up a custom domain for the Talk HPB:

1. Add a subdomain (e.g., `talk.yourdomain.com`) pointing to the Talk HPB service
2. Update the NextCloud Talk settings in admin panel

### TURN Server Configuration

The template includes TURN server configuration. To verify:

1. Go to Settings > Administration > Talk
2. Check that TURN servers are properly configured
3. Test with multiple participants from different networks

## Troubleshooting

### Security Warnings Still Showing

- Wait 5-10 minutes after deployment for all background jobs to complete
- Check the logs: `railway logs --service nextcloud`
- Manually run: `php occ db:add-missing-indices`

### Talk HPB Not Working

- Verify the HPB service is running: `railway logs --service talk-hpb`
- Check the signaling URL in Talk settings
- Ensure secrets match between services

### Performance Issues

- Monitor resource usage in Railway dashboard
- Consider upgrading to higher-tier plans for more resources
- Check Redis memory usage

## Environment Variables

Key environment variables (automatically configured):

| Variable | Description | Default |
|----------|-------------|---------|
| `MYSQL_HOST` | Database connection | Auto-generated |
| `REDIS_HOST` | Redis connection | Auto-generated |
| `NEXTCLOUD_TRUSTED_DOMAINS` | Trusted domains | Railway domain |
| `SIGNALING_SECRET` | Talk HPB secret | Auto-generated |
| `PHP_MEMORY_LIMIT` | PHP memory limit | 512M |
| `PHP_UPLOAD_LIMIT` | Upload limit | 2G |

## Advanced Configuration

### Custom Apps

Upload custom apps to the persistent volume or install via the app store.

### Database Tuning

For high-traffic instances, consider adjusting:
- `MYSQL_INNODB_BUFFER_POOL_SIZE`
- `REDIS_MAXMEMORY`

### Backup Strategy

Set up regular backups:
1. Database dumps using Railway's backup features
2. File storage backup (consider external storage)

## Support

- Railway Documentation: https://docs.railway.app
- NextCloud Documentation: https://docs.nextcloud.com
- Issues: Create an issue in this repository

## Contributing

Feel free to submit issues and enhancement requests!

## License

This template is provided as-is under the MIT License.
