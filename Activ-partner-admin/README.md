# Activ Partner Admin

Backend URLs are loaded by Vite from `.env`. Use `.env.example` as the template
when setting up a new checkout.

- `VITE_LOCAL_API_URL`: optional local backend, including `/api/v1`.
- `VITE_API_URL`: optional deployed backend, including `/api/v1`.

Set at least one URL. With both configured, the admin tries the local backend
first and falls back to the deployed backend when local is unreachable. Leave
`VITE_LOCAL_API_URL` blank for deployments that should use only Render.

Run `npm run dev` for development or `npm run build` for a production build.
Restart Vite after changing `.env`; rebuild for production changes.

These variables are public in the browser bundle. Keep passwords and private
keys in the backend environment only. Local `.env` files are ignored by Git.

## Vercel Deployment

Set the project Root Directory to `Activ-partner-admin`, the framework to Vite,
the build command to `npm run build`, and the output directory to `dist`.

In Project Settings > Environment Variables, add:

```env
VITE_API_URL=https://activ-partner.onrender.com/api/v1
```

Enable it for Production and Preview as needed. Leave `VITE_LOCAL_API_URL`
unset on Vercel so visitors do not connect to their own localhost.
Redeploy after saving: Vite embeds these values at build time, so changing
variables does not update an existing deployment. Your ignored local `.env`
is not uploaded from Git. Builds fail early if neither API URL is configured.
