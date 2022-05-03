// это файл для тестирования с локального компьютера
// запускайте его для проверки и тестирования своего кода перед развертыванием функции
import { driver, initDb } from './database';
import { createClientTable, insertValues } from './queries/clients-table';

async function main() {
  await initDb();

  const apiKey = 'apiKey22';
  await createClientTable(apiKey);
  await insertValues(apiKey);
  await driver.destroy();
}

main();
