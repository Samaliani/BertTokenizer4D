unit Decode;

interface

uses
  DUnitX.TestFramework,
  BertTokenizer;

type
  {$M+}
  [TestFixture('Decode')]
  TDecodeTests = class
  private
    FTokenizer: TBertTokenizer;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure DecodeStartingFromSuffix();

    [Test]
    procedure DecodeEmpty();
  end;

implementation

uses
  SysUtils;

{ TDecodeTests }

procedure TDecodeTests.DecodeEmpty;
var
  Empty: TArray<Integer>;
  Decoded: string;
begin
  SetLength(Empty, 0);
  Decoded := FTokenizer.Decode(Empty);
  Assert.AreEqual(Decoded, String.Empty);
end;

procedure TDecodeTests.DecodeStartingFromSuffix;
var
  LoremIpsum: TArray<Integer>;
  Decoded: string;
begin
  // 19544 is lore
  // 2213 is ##m
  LoremIpsum := [101, 19544, 2213, 12997, 17421, 2079, 10626, 4133, 2572, 3388, 1012, 102];
  Decoded := FTokenizer.Decode(LoremIpsum);
  Assert.StartsWith('[CLS] lorem ipsum', Decoded);

  LoremIpsum := Copy(LoremIpsum, 2, Length(LoremIpsum));
  Decoded := FTokenizer.Decode(LoremIpsum);
  Assert.StartsWith('##m ipsum', Decoded);
end;

procedure TDecodeTests.Setup;
begin
  FTokenizer := TBertTokenizer.Create;
  // TODO Load from LoadTokenizerJsonAsync("data/bert-base-uncased/tokenizer.json");
  FTokenizer.LoadVocabulary('../../../../data/bert-base-uncased/vocab.txt', True);
end;

procedure TDecodeTests.TearDown;
begin
  FTokenizer.Free;
end;

initialization
  //Register the test fixtures
  TDUnitX.RegisterTestFixture(TDecodeTests);

end.
