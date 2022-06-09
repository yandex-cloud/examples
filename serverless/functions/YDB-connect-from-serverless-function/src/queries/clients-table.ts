import { driver } from '../database';
import { TypedData, Types } from 'ydb-sdk';
import { TableDescription2 } from './helpers';
import { v4 as uuidv4 } from 'uuid';

export async function createClientTable(apiKey: string) {
  await driver.tableClient.withSession(async (session) => {
    await session.dropTable(`${apiKey}`);

    await session.createTable(
      `${apiKey}`,

      new TableDescription2()
        .withColumns2([
          { n: 'products_id', t: Types.UTF8 },
          { n: 'products_name', t: Types.UTF8 },
          { n: 'price_baz', t: Types.DOUBLE },
        ])
        .withPrimaryKey('products_id'),
    );
  });
}

export async function insertValues(apiKey: string) {
  // для первичного ключа отлично подходит uuid
  // UPSERT и REPLACE являются операциями модификации данных, которые не требует их предварительного чтения, за счет чего работают быстрее и дешевле других операций.
  const query = `
    upsert INTO ${apiKey} (products_id, products_name, price_baz)
    VALUES ('${uuidv4()}', 'Яблочный край', 1414);
  `;

  await driver.tableClient.withSession(async (session) => {
    await session.executeQuery(query);
  });
}
