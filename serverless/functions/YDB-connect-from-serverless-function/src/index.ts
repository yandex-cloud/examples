require("dotenv").config(".env");
import { YC } from "./yc";
import {
  getLogger,
  Driver,
  Logger,
  MetadataAuthService,
  Session,
} from "ydb-sdk";

const databaseName = process.env.DATABASENAME!;
const logger = getLogger({ level: process.env.YDB_SDK_LOGLEVEL! });
const entryPoint = process.env.ENTRYPOINT!;
let driver: Driver = null as unknown as Driver; // singleton

module.exports.handler = async function (
  event: YC.CloudFunctionsHttpEvent,
  context: YC.CloudFunctionsContext
) {
  const { httpMethod, queryStringParameters } = event;

  if (httpMethod != "GET")
    return {
      statusCode: 405,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        errMsg: "Используйте метод GET ",
      }),
      isBase64Encoded: false,
    };

  await initYDBdriver();

  const outObject: any = driver ? { driver: true } : { driver: false };

  await driver.tableClient.withSession(async (session) => {
    outObject.tableDef = await describeTable(session, "series", logger);
  });

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(outObject),
    isBase64Encoded: false,
  };
};

export async function initYDBdriver() {
  if (driver) return;
  logger.info("Start preparing driver ...");
  const authService = new MetadataAuthService(databaseName);
  driver = new Driver(entryPoint, databaseName, authService);

  if (!(await driver.ready(10000))) {
    logger.fatal(`Driver has not become ready in 10 seconds!`);
    process.exit(1);
  }
  return driver;
}

export async function describeTable(
  session: Session,
  tableName: string,
  logger: Logger
) {
  logger.info(`Describing table: ${tableName}`);
  const result = await session.describeTable(tableName);
  const resultObj: any = { info: `Describe table  ${tableName}` };
  const columns = [];
  for (const column of result.columns) {
    columns.push({
      name: column.name,
      type: column.type!.optionalType!.item!.typeId!,
    });
  }
  resultObj.columns = columns;
  return resultObj;
}
