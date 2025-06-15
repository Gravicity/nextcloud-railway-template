# NextCloud Railway Template

A production-ready NextCloud deployment for Railway.com with PostgreSQL, Redis, and security optimizations.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/YLCYUz?referralCode=CGGc7W)

## ✅ What's Included

- **NextCloud** with PostgreSQL and Redis
- **Security optimizations** - PHP OPcache, security headers
- **Performance tuning** - Database indices, caching configuration  
- **Railway integration** - Optimized for Railway deployment
- **Fix script** - Resolves NextCloud security warnings

## 🚀 Deploy

1. **Create Railway project** and add services:
   - Add PostgreSQL service
   - Add Redis service
   - Add this repository as a service (or fork first if you want to customize)
2. **Set environment variables** in Railway dashboard:
   ```
   # Database Configuration (Railway provides these automatically)
   PGHOST=${{Postgres.PGHOST}}
   PGPORT=${{Postgres.PGPORT}}
   PGUSER=${{Postgres.PGUSER}}
   PGPASSWORD=${{Postgres.PGPASSWORD}}
   PGDATABASE=${{Postgres.PGDATABASE}}
   
   # Redis Configuration (Railway provides these automatically)
   REDISHOST=${{Redis.REDISHOST}}
   REDISPORT=${{Redis.REDISPORT}}
   REDISPASSWORD=${{Redis.REDISPASSWORD}}
   
   # NextCloud Configuration (Required)
   NEXTCLOUD_TRUSTED_DOMAINS=${{RAILWAY_PUBLIC_DOMAIN}} localhost
   NEXTCLOUD_DATA_DIR=/var/www/html/data
   NEXTCLOUD_TABLE_PREFIX=oc_
   
   # NextCloud Admin (Only set these for automatic setup)
   # NEXTCLOUD_ADMIN_USER=admin
   # NEXTCLOUD_ADMIN_PASSWORD=secure_password_here
   
   # Optional Performance Settings
   # PHP_MEMORY_LIMIT=512M
   # PHP_UPLOAD_LIMIT=2G
   # NEXTCLOUD_UPDATE_CHECKER=false
   ```
   
   > **Setup Options:**
   > - **Manual Setup** (Recommended): Don't set `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD` variables at all - use the web setup wizard
   > - **Automatic Setup**: Uncomment and set both `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD` for complete automation
   > 
   > **Important:** Database and Redis connections are pre-configured automatically in both cases.
   
   > **Security:** If using automatic setup, use a strong password for `NEXTCLOUD_ADMIN_PASSWORD`.
   
   > **Note:** `NEXTCLOUD_TRUSTED_DOMAINS` uses the public domain for security validation (allowed access domains), not for outbound connections, so no egress fees apply.

## 🔧 Post-Deployment

### Step 1: Complete NextCloud Setup
1. **Visit your Railway URL** - you should see the NextCloud setup wizard
2. **Create your admin account** using the web interface
3. **Wait for setup to complete** - you should see the NextCloud dashboard

### Step 2: Fix Security Warnings (Optional)
**IMPORTANT**: Only run this AFTER step 1 is complete.

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and connect to your project
railway login
railway link

# Run the fix script (only after setup is complete)
railway run /usr/local/bin/fix-warnings.sh
```

This automatically:
- Adds missing database columns/indices
- Runs mimetype migrations
- Configures maintenance window  
- Sets default phone region
- Enables Redis caching

## 🏆 Performance Backend (Optional)

For video calling, add a Talk High Performance Backend:

1. **Add new service** → **Docker Image**
2. **Image**: `ghcr.io/nextcloud-releases/aio-talk:latest`
3. **Environment variables**:
   ```
   NC_DOMAIN=${{RAILWAY_PUBLIC_DOMAIN}}
   SIGNALING_SECRET=generate_32_char_secret
   TURN_SECRET=generate_32_char_secret  
   INTERNAL_SECRET=generate_32_char_secret
   ```
4. **In NextCloud service**, add:
   ```
   SIGNALING_SECRET=same_as_hpb_secret
   HPB_URL=https://your-hpb-domain.railway.app
   ```

Generate secrets: `openssl rand -hex 32`

## 📊 Environment Variables

### Database (Auto-configured by Railway):
- `PGHOST` - PostgreSQL host (Railway provides automatically)
- `PGPORT` - PostgreSQL port (Railway provides automatically)  
- `PGUSER` - PostgreSQL username (Railway provides automatically)
- `PGPASSWORD` - PostgreSQL password (Railway provides automatically)
- `PGDATABASE` - PostgreSQL database name (Railway provides automatically)

### Redis (Auto-configured by Railway):
- `REDISHOST` - Redis host (set to `${{Redis.REDISHOST}}`)
- `REDISPORT` - Redis port (set to `${{Redis.REDISPORT}}`)
- `REDISPASSWORD` - Redis password (set to `${{Redis.REDISPASSWORD}}`)

### NextCloud Configuration (Required):
- `NEXTCLOUD_TRUSTED_DOMAINS` - Allowed domains for access security

### NextCloud Admin (Optional - for automatic setup):
- `NEXTCLOUD_ADMIN_USER` - Admin username for automatic setup
- `NEXTCLOUD_ADMIN_PASSWORD` - Admin password for automatic setup
- **Don't set these variables at all to use the web setup wizard instead**

### NextCloud Required Settings:
- `NEXTCLOUD_DATA_DIR` - Data directory path (set to `/var/www/html/data`)
- `NEXTCLOUD_TABLE_PREFIX` - Database table prefix (set to `oc_`)

### NextCloud Optional Settings:
- `NEXTCLOUD_UPDATE_CHECKER` - Enable update checker (default: `false`)
- `PHP_MEMORY_LIMIT` - PHP memory limit (default: `512M`)
- `PHP_UPLOAD_LIMIT` - File upload size limit (default: `2G`)

### Talk High Performance Backend (Optional):
- `SIGNALING_SECRET` - Talk HPB secret
- `HPB_URL` - Talk HPB service URL

## 🐛 Troubleshooting

**Missing PostgreSQL environment variables:** Make sure you've set all environment variables in the Railway dashboard exactly as shown above. The service references like `${{Postgres.PGHOST}}` should auto-populate from your PostgreSQL service.

**Setup wizard shows database fields:** Database should be pre-configured automatically. If you see database fields, check Railway logs for configuration errors.

**PostgreSQL connection fails:** Ensure all `PG*` environment variables are correctly set with Railway service references (PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE).

**Redis connection fails:** Ensure all Redis environment variables are correctly set (REDISHOST, REDISPORT, REDISPASSWORD).

**Security warnings:** Run the fix script after completing setup.

**Performance issues:** Consider upgrading Railway plan or adding Talk HPB.

## 📖 Resources

- [NextCloud Documentation](https://docs.nextcloud.com/)
- [Railway Documentation](https://docs.railway.com/)

---

**🎉 Deploy NextCloud with zero security warnings on Railway!**
