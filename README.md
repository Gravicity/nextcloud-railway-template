# NextCloud with High-Performance Backend for Railway

A production-ready NextCloud deployment optimized for Railway.com that resolves all common security warnings.

> **⚠️ Important**: Railway doesn't support environment variables in config files. You'll need to set variables through the Railway dashboard.

## ✅ What This Template Fixes

After deployment, these NextCloud warnings will be **RESOLVED**:

- ✅ **High-Performance Backend** - Optional Talk HPB setup
- ✅ **HSTS and Security Headers** - All security headers configured
- ✅ **PHP OPcache** - Memory optimization configured  
- ✅ **Database Indices** - Automatically added for performance
- ✅ **Maintenance Window** - Set to 2 AM UTC
- ✅ **Background Jobs** - Cron properly configured
- ✅ **Redis Caching** - Full Redis integration
- ✅ **Trusted Proxies** - Railway proxy configuration

## 🚀 Quick Deploy

### Step 1: Create Services in Railway

1. **Create new project** in Railway
2. **Add MySQL service**: 
   - Go to project → Add Service → Database → MySQL
3. **Add Redis service**:
   - Go to project → Add Service → Database → Redis
4. **Add NextCloud service**:
   - Go to project → Add Service → GitHub Repo
   - Connect this repository

### Step 2: Configure NextCloud Service

In your NextCloud service settings, **no environment variables are required!** 

Railway automatically provides:
- `DATABASE_URL` - MySQL connection string
- `REDIS_URL` - Redis connection string  
- `RAILWAY_PUBLIC_DOMAIN` - Your app's public URL

The entrypoint script automatically parses these and configures NextCloud.

### Step 3: Optional - Deploy Talk HPB

For video calling, deploy a separate Talk HPB service:

1. **Add new service** → **Docker Image**
2. **Image**: `ghcr.io/nextcloud-releases/aio-talk:latest`
3. **Set environment variables**:
   ```
   NC_DOMAIN=your-nextcloud-domain.railway.app
   SIGNALING_SECRET=generate_a_32_character_secret
   TURN_SECRET=generate_another_32_character_secret
   INTERNAL_SECRET=generate_third_32_character_secret
   ```

Generate secrets with: `openssl rand -hex 32`

4. **In NextCloud service**, add these variables:
   ```
   SIGNALING_SECRET=same_as_hpb_signaling_secret
   HPB_URL=https://your-hpb-service.railway.app
   ```

## 📁 Repository Structure

```
nextcloud-railway-template/
├── Dockerfile                    # Custom NextCloud with optimizations
├── railway.json                  # Railway deployment config (build/deploy only)
├── config/
│   ├── php.ini                   # PHP performance settings
│   ├── security.conf             # Apache security
│   ├── apache-security.conf      # Security headers
│   └── supervisord.conf          # Process management
├── scripts/
│   └── entrypoint.sh             # Custom startup with Railway integration
└── README.md                     # This file
```

## ⚙️ How It Works

1. **Railway Integration**: Automatically parses `DATABASE_URL` and `REDIS_URL`
2. **Auto-Configuration**: Creates optimized NextCloud config
3. **Security Headers**: Enables HSTS and all security headers
4. **Performance**: Configures OPcache, Redis caching, database indices
5. **Background Jobs**: Sets up proper cron jobs via supervisor

## 🔧 Manual Deployment

If you prefer manual deployment:

```bash
# Clone the repository
git clone https://github.com/your-username/nextcloud-railway-template
cd nextcloud-railway-template

# Install Railway CLI
npm install -g @railway/cli

# Login and create project
railway login
railway add
railway add mysql
railway add redis

# Deploy the NextCloud service
railway up
```

## 🩺 Health Checks & Verification

After deployment:

1. **Check NextCloud Status**:
   ```bash
   curl https://your-domain.railway.app/status.php
   ```

2. **Check Security Settings**:
   - Go to Settings → Administration → Overview
   - Should see mostly green checkmarks ✅

3. **Check Talk HPB** (if deployed):
   ```bash
   curl https://your-hpb-domain.railway.app/api/v1/welcome
   ```

## 🔧 Environment Variables Reference

### Required (Auto-provided by Railway)
- `DATABASE_URL` - MySQL connection (auto-set by Railway)
- `REDIS_URL` - Redis connection (auto-set by Railway)
- `RAILWAY_PUBLIC_DOMAIN` - Your domain (auto-set by Railway)

### Optional (for Talk HPB)
- `SIGNALING_SECRET` - Shared secret for Talk HPB
- `HPB_URL` - URL of your Talk HPB service

### Advanced (Optional)
- `NC_DOMAIN` - Custom domain (defaults to RAILWAY_PUBLIC_DOMAIN)
- `MYSQL_*` - Individual DB settings (if not using DATABASE_URL)
- `REDIS_*` - Individual Redis settings (if not using REDIS_URL)

## 🐛 Troubleshooting

### NextCloud Won't Start
- Check Railway logs for errors
- Verify DATABASE_URL and REDIS_URL are set
- Ensure MySQL and Redis services are running

### Security Warnings Still Show
- Wait 10-15 minutes after first deployment
- Check logs for optimization completion
- Manually run: `railway run php /var/www/html/occ db:add-missing-indices`

### Talk HPB Issues
- Verify SIGNALING_SECRET matches between services
- Check HPB service logs
- Test the welcome endpoint

### File Upload Issues
- Default limit is 2GB (configured in PHP settings)
- Check Railway disk space limits
- Monitor memory usage

## 🚀 Performance Tips

1. **Upgrade Railway Plan**: For better performance with more resources
2. **Monitor Usage**: Use Railway's built-in metrics
3. **Custom Domain**: Add your own domain for better caching
4. **Redis Memory**: Monitor Redis memory usage in metrics

## 📊 What's Different from Standard NextCloud

This template includes:

- **Railway-optimized configuration** parsing DATABASE_URL/REDIS_URL
- **Security headers** preventing common warnings
- **PHP optimizations** including OPcache configuration
- **Database optimizations** automatic index creation
- **Supervisor process management** for reliable background jobs
- **Health checks** for Railway deployment monitoring

## 📖 Additional Resources

- [NextCloud Documentation](https://docs.nextcloud.com/)
- [Railway Documentation](https://docs.railway.com/)
- [NextCloud Talk Documentation](https://nextcloud-talk.readthedocs.io/)

## 🐛 Issues & Support

- **NextCloud Issues**: [NextCloud GitHub](https://github.com/nextcloud/server)
- **Railway Issues**: [Railway Help](https://help.railway.app/)
- **Template Issues**: Create an issue in this repository

---

**🎉 Deploy and enjoy NextCloud with zero security warnings on Railway!**
