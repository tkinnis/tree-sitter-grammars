program Shapes;

type
  TList = specialize TFPGList<Integer>;
  TMap = specialize TFPGMap<string, TList>;

var
  Items: TList;
  Kind: Integer;

begin
  case Kind of
    Small: Items := nil;
    Low .. High: Kind := 1;
  end;
end.
