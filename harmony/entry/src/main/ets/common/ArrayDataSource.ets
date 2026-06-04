export class ArrayDataSource<T extends Object> implements IDataSource {
  private readonly items: T[];
  private listeners: DataChangeListener[] = [];

  constructor(items: T[]) {
    // LazyForEach 只通过 getData 读取当前快照，复制数组可以避免构建期间被外部原地修改。
    this.items = items.slice();
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): T {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener);
  }
}
