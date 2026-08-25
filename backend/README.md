# Pawside hatch backend

Node 22 + TypeScript + Hono service for SPEC 015 rig pack hatching. It accepts 1–3 pet photos,
classifies the first photo, queues supported pets, generates the four canonical poses with Gemini,
removes their solid backgrounds, detects rig boxes, and writes a flat `.pettodopet` rig pack.

## Storage choice

V1 uses an atomically replaced JSON state file (`data/state.json`) plus pack files under
`data/packs/`. This is the smallest implementation for the specified single-process queue: it has no
native database dependency, and quota reservation plus job creation remain one synchronous operation
inside one Node process. Incubating jobs are marked failed after a process restart because their photo
buffers only live in the V1 queue.

This storage model requires exactly one application replica and a persistent disk. Before horizontal
scaling, move job claims, counters, and status transitions to a transactional shared database/object
store.

## Local development

```sh
cd backend
cp .env.example .env
# Export the values from .env in your preferred shell/process manager.
npm install
npm run typecheck
npm test
npm run build
GEMINI_API_KEY=... npm start
```

`GEMINI_API_KEY` is read only from the process environment. The service does not load or persist it.
Important variables:

- `PORT`: HTTP port, default `3000`.
- `DATA_DIR`: state and pack directory, default `./data`.
- `GLOBAL_DAILY_HATCH_LIMIT`: Gemini classification attempts (cost slots) per UTC day, default `200`.

Each device can reserve at most three accepted cat/dog hatches. Unsupported species do not consume a
reservation. The global daily guard returns `503 {"code":"daily_limit_reached"}` without calling
Gemini.

## API

- `POST /v1/hatch`: multipart `photos[]` (1–3 JPEG/PNG), optional `petName`, and UUID
  `X-Device-Id` header.
- `GET /v1/hatch/{id}`: same device header; `packUrl` appears only when status is `ready`.
- `POST /v1/species-wish`: JSON `{ "speciesText": "..." }`.
- `GET /v1/packs/{id}.pettodopet`: direct pack download used by a ready job's `packUrl`.

## DigitalOcean Droplet deployment

Use one Docker-enabled DigitalOcean Droplet (not a multi-replica App Platform service) so the V1
single-process queue and local JSON state keep their required semantics.

1. Build the image from `backend/Dockerfile` and push it to DigitalOcean Container Registry.
2. Create `/var/lib/pawside-hatch` on the Droplet and back it up as persistent application data.
3. Run exactly one container, mounting that directory at `/app/data`, setting `GEMINI_API_KEY` as a
   secret environment variable, and optionally setting `GLOBAL_DAILY_HATCH_LIMIT`.
4. Put HTTPS (Caddy or the DigitalOcean load balancer) in front of container port `3000`; the public
   request origin is used to construct direct `packUrl` values.

Example container invocation (replace the image name and secret source):

```sh
docker run -d --restart unless-stopped --name pawside-hatch \
  -p 127.0.0.1:3000:3000 \
  -v /var/lib/pawside-hatch:/app/data \
  -e GEMINI_API_KEY \
  -e GLOBAL_DAILY_HATCH_LIMIT=200 \
  registry.digitalocean.com/example/pawside-hatch:latest
```

> 绑定挂载数据目录时,宿主目录须归容器用户所有:`sudo chown -R 1000:1000 <数据目录>`,否则容器无法写入 state.json 与 packs/。

`PUBLIC_BASE_URL`(反向代理部署必设):对外 origin,ready 响应的 packUrl 以它拼接;不设则回退请求 origin(仅适合直连部署)。Docker 运行示例:`-e PUBLIC_BASE_URL=https://api.pawside.app`。
