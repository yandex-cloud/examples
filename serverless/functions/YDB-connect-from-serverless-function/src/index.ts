import { YC } from './yc';
import { driver, initDb } from './database';
import { createClientTable, insertValues } from './queries/clients-table';

export async function handler(event: YC.CloudFunctionsHttpEvent, context: YC.CloudFunctionsHttpContext) {
  // возможно Вы захотите передать в функцию какие то параметры в get строке
  const { api_key, format, fields, brands } = event.queryStringParameters;

  if (!api_key) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: { error: 'Вам необходимо указать параметр api_key' },
      isBase64Encoded: false,
    };
  }
  await initDb();

  await createClientTable(api_key);
  await insertValues(api_key);

  await driver.destroy();

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: { info: `Создана таблица ${api_key}, вставлена одна запись` },
    isBase64Encoded: false,
  };
}
