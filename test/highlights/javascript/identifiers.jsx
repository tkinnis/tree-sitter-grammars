import React from 'react';

@inject('store')
class Panel extends React.Component {
  @observable.ref items = [];
  @persist.as('rows') rows = [];

  constructor(props) {
    super(props);
    this.url = new URL(props.href);
    this.limit = Math.max(MAX_ITEMS, LIMIT());
  }

  @action.bound
  render() {
    return <Layout.Row className="panel">{this.items}<Layout.Gap /></Layout.Row>;
  }
}
