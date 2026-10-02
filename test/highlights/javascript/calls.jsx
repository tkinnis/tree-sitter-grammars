function render(props) {
  const shown = eval(props.code) < 2;
  return <div>{shown && parseInt(props.count)}</div>;
}
