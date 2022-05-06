import { Column, TableDescription, Types } from 'ydb-sdk';

export interface IColumnDescription {
  n: string;
  t: Types;
}

export class TableDescription2 extends TableDescription {
  constructor() {
    super();
  }
  public withColumns2(columns: Array<IColumnDescription>) {
    for (const column of columns) {
      this.columns.push(new Column(column.n, Types.optional(column.t)));
    }
    return this;
  }
}
