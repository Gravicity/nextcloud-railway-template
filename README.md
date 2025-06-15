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
   # Database Configuration (required - Railway doesn't auto-provide POSTGRES_HOST)
   POSTGRES_HOST=${{Postgres.RAILWAY_PRIVATE_DOMAIN}}
   
   # NextCloud Configuration
   NEXTCLOUD_TRUSTED_DOMAINS=${{RAILWAY_PUBLIC_DOMAIN}} localhost
   ```
   
   > **Note:** Railway automatically provides `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` when you add a PostgreSQL service. You only need to manually set `POSTGRES_HOST` and `NEXTCLOUD_TRUSTED_DOMAINS`.

   > **Important:** Database connection is pre-configured automatically. You'll only need to create an admin account through the setup wizard.
   
   > **Note:** `NEXTCLOUD_TRUSTED_DOMAINS` uses the public domain for security validation (allowed access domains), not for outbound connections, so no egress fees apply.

## 🔧 Post-Deployment

After deployment, fix security warnings using Railway CLI:

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and connect to your project
railway login
railway link

# Run the fix script
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

### User Setup:
- Create admin account through web setup wizard (database pre-configured)

### Optional (for Talk):
- `SIGNALING_SECRET` - Talk HPB secret
- `HPB_URL` - Talk HPB service URL

## 🐛 Troubleshooting

**Missing PostgreSQL environment variables:** Make sure you've set all environment variables in the Railway dashboard exactly as shown above. The service references like `${{Postgres.PGUSER}}` should auto-populate from your PostgreSQL service.

**Setup wizard shows database fields:** Database should be pre-configured automatically. If you see database fields, check Railway logs for configuration errors.

**PostgreSQL connection fails:** Ensure all `POSTGRES_*` environment variables are correctly set with Railway service references.

**Security warnings:** Run the fix script after completing setup.

**Performance issues:** Consider upgrading Railway plan or adding Talk HPB.

## 📖 Resources

- [NextCloud Documentation](https://docs.nextcloud.com/)
- [Railway Documentation](https://docs.railway.com/)

---

**🎉 Deploy NextCloud with zero security warnings on Railway!**
