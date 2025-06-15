# NextCloud Railway Template

A production-ready NextCloud deployment for Railway.com with PostgreSQL, Redis, and security optimizations.

## ✅ What's Included

- **NextCloud** with PostgreSQL and Redis
- **Security optimizations** - PHP OPcache, security headers
- **Performance tuning** - Database indices, caching configuration  
- **Railway integration** - Optimized for Railway deployment
- **Fix script** - Resolves NextCloud security warnings

## 🚀 Deploy

### Option 1: Use This Repository Directly

1. **Fork this repository** to your GitHub account
2. **Create Railway project** and add services:
   - Add PostgreSQL service
   - Add Redis service
   - Add this repository as a service
3. **Set environment variables** in Railway dashboard:
   - `POSTGRES_HOST`: `${{Postgres.RAILWAY_PRIVATE_DOMAIN}}`
   - `POSTGRES_USER`: `${{Postgres.PGUSER}}`
   - `POSTGRES_PASSWORD`: `${{Postgres.POSTGRES_PASSWORD}}`
   - `POSTGRES_DB`: `${{Postgres.POSTGRES_DB}}`
   - `REDIS_HOST`: `${{Redis.RAILWAY_PRIVATE_DOMAIN}}`
   - `REDIS_HOST_PORT`: `${{Redis.REDISPORT}}`
   - `REDIS_HOST_PASSWORD`: `${{Redis.REDIS_PASSWORD}}`
   - `NEXTCLOUD_TRUSTED_DOMAINS`: `${{RAILWAY_PUBLIC_DOMAIN}} localhost`
   - `NEXTCLOUD_ADMIN_USER`: Your admin username
   - `NEXTCLOUD_ADMIN_PASSWORD`: Your admin password

### Option 2: Deploy from Template (When Available)

Once published as a Railway template, you'll be able to one-click deploy.

## 🔧 Post-Deployment

After deployment, fix security warnings:

```bash
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

### Auto-configured by template:
- `POSTGRES_*` - Database connection
- `REDIS_*` - Cache connection
- `NEXTCLOUD_TRUSTED_DOMAINS` - Railway domain

### Required (you set):
- `NEXTCLOUD_ADMIN_USER` - Admin username
- `NEXTCLOUD_ADMIN_PASSWORD` - Admin password

### Optional (for Talk):
- `SIGNALING_SECRET` - Talk HPB secret
- `HPB_URL` - Talk HPB service URL

## 🐛 Troubleshooting

**Setup screen still shows:** This is normal - enter your admin credentials and click Install. Database will auto-configure.

**Security warnings:** Run the fix script after deployment.

**Performance issues:** Consider upgrading Railway plan or adding Talk HPB.

## 📖 Resources

- [NextCloud Documentation](https://docs.nextcloud.com/)
- [Railway Documentation](https://docs.railway.com/)

---

**🎉 Deploy NextCloud with zero security warnings on Railway!**
