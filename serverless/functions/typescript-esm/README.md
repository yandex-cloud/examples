# Сloud function on TypeScript with ES-modules
Example of cloud function written in TypeScript and deployed as native ES-modules.
See [documentation](https://cloud.yandex.ru/docs/functions/lang/nodejs/esm) for details.

## Usage
Install dependencies:
```
npm install
```

Compile TypeScript to `./dist`:
```
npm run build
```

Create cloud function via [yc cli](https://cloud.yandex.ru/docs/cli/) (once):
```
yc serverless function create --name typescript-esm
```

Deploy cloud function version from `./dist`:
```
yc serverless function version create  \
  --function-name typescript-esm       \
  --memory 128m                        \
  --execution-timeout 5s               \
  --runtime nodejs16                   \
  --entrypoint cjs/index.handler       \
  --source-path ./dist                 
```

Invoke function:
```
yc serverless function invoke --name typescript-esm
```
Response:
```
{"body":"https://example.com responded with status: 200"}
```