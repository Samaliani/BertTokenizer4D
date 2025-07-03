unit BertTokenizer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections;

{$SCOPEDENUMS ON}

type
  ETokenizerException = class(Exception);

  // Not used currently
  TNormalizationForm = (
    FormC = 1,
    FormD = 2,
    FormKC = 5,
    FormKD = 6
  );

  TBertTokenizer = class
  private
    FPrefixes: TDictionary<string, Integer>;
    FSuffixes: TDictionary<string, Integer>;
    FDecodePrefixes: TDictionary<Integer, string>;
    FDecodeSuffixes: TDictionary<Integer, string>;
    FDecoderPrefix: string;
    FNormalization: TNormalizationForm; // not supported currently
    FCleanupTokenizationSpaces: Boolean; // not supported currently
    FConvertInputToLowercase: Boolean;
    FUnkId, FClsId, FSepId, FPadId: Integer;
    procedure CheckVocabulary;
    function EmitNoSpaceBefore(const APrefix: string): Boolean;
    function NormalizeText(const AText: string): string;
    function PreProcessText(const AText: string): TArray<string>;
    function TokenizeSubword(const AWord: string; Tokens: TList<Integer>): Integer;
    function Tokenize(const AText: string): TList<Integer>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadVocabulary(const AFileName: string; ConvertInputToLowercase: Boolean;
      const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
      const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
    procedure LoadVocabularyFromStream(Stream: TStream; ConvertInputToLowercase: Boolean;
      const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
      const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
    procedure LoadTokenizerJson(const AFileName: string);
    procedure LoadTokenizerJsonFromStream(Stream: TStream);

    function Encode(const AText: string): TArray<Integer>;
    function Decode(const ATokens: TArray<Integer>): string;
  end;

implementation

uses
  System.Character,
  BertTokenizer.Loader,
  BertTokenizer.Json;

type
  TDictionaryReverser = class
    class function Reverse<K, V>(const ADictionary: TDictionary<K, V>): TDictionary<V, K>;
  end;

procedure ReadLoaderData(Tokenizer: TBertTokenizer; Loader: TBertTokenizerLoader);
begin
  Tokenizer.FPrefixes.Free;
  Tokenizer.FSuffixes.Free;
  Tokenizer.FDecodePrefixes.Free;
  Tokenizer.FDecodeSuffixes.Free;

  Tokenizer.FPrefixes := Loader.Prefixes;
  Tokenizer.FSuffixes := Loader.Suffixes;

  Tokenizer.FDecoderPrefix := Loader.SuffixPrefix;
  Tokenizer.FConvertInputToLowercase := Loader.ConvertInputToLowercase;
  Tokenizer.FNormalization := Loader.Normalization;

  // TODO: More props currenty not supported
  // strip_accents (bool, optional) – Whether to strip all accents. If this option is not specified (ie == None), then it will be determined by the value for lowercase (as in the original Bert).
  //_stripAccents = tok.Normalizer.StripAccents ?? _lowercaseInput;
  //_decoderPrefix = tok.Decoder?.Prefix ?? "##";
  Tokenizer.FCleanupTokenizationSpaces := Loader.CleanupTokenizationSpaces; //_cleanupTokenizationSpaces = tok.Decoder?.Cleanup ?? true;



  // Maybe we need string representation as well at some point
  Tokenizer.FUnkId := Loader.UnkId;
  Tokenizer.FClsId := Loader.ClsId;
  Tokenizer.FSepId := Loader.SepId;
  Tokenizer.FPadId := Loader.PadId;
end;

{ TDictionaryReverser }

class function TDictionaryReverser.Reverse<K, V>(const ADictionary: TDictionary<K, V>): TDictionary<V, K>;
var
  Pair: TPair<K, V>;
begin
  Result := TDictionary<V, K>.Create;
  for Pair in ADictionary do
    Result.Add(Pair.Value, Pair.Key);
end;

{ TBertTokenizer }

constructor TBertTokenizer.Create;
begin
  inherited Create;
  FCleanupTokenizationSpaces := True;
end;

destructor TBertTokenizer.Destroy;
begin
  FPrefixes.Free;
  FSuffixes.Free;
  FDecodePrefixes.Free;
  FDecodeSuffixes.Free;
  inherited;
end;

// See https://github.com/huggingface/tokenizers/blob/daf361676bdfd14088f7e0bc087effc6a9cfdf3e/tokenizers/src/decoders/wordpiece.rs#L31
function TBertTokenizer.EmitNoSpaceBefore(const APrefix: string): Boolean;
begin
  Result := (APrefix = '.') or
    (APrefix = '?') or
    (APrefix = '!') or
    (APrefix = ',');
end;

procedure TBertTokenizer.CheckVocabulary;
begin
  if FPrefixes = nil then
    raise ETokenizerException.Create('Vocabulary not loaded');
  if FSuffixes = nil then
    raise ETokenizerException.Create('Vocabulary not loaded');
end;

function TBertTokenizer.Decode(const ATokens: TArray<Integer>): string;
var
  StringBuilder: TStringBuilder;
  Prefix, Suffix: string;
  I: Integer;
begin
  CheckVocabulary;

  Result := '';
  if FDecodePrefixes = nil then
    FDecodePrefixes := TDictionaryReverser.Reverse<string, Integer>(FPrefixes);
  if FDecodeSuffixes = nil then
    FDecodeSuffixes := TDictionaryReverser.Reverse<string, Integer>(FSuffixes);

  if Length(ATokens) = 0 then
    Exit;

  StringBuilder := TStringBuilder.Create();
  try
    if FDecodePrefixes.TryGetValue(ATokens[0], Prefix) then
      StringBuilder.Append(Prefix)
    else
    begin
      // Our decoded text does not start with a word start but in the middle of a word.
      StringBuilder.Append(FDecoderPrefix);
      StringBuilder.Append(FDecodeSuffixes[ATokens[0]]);
    end;

    for I := 1 to Length(ATokens) -1  do
    begin
      if FDecodePrefixes.TryGetValue(ATokens[I], Prefix) then
      begin
        if (not FCleanupTokenizationSpaces) or (not EmitNoSpaceBefore(Prefix)) then
          StringBuilder.Append(' ');
        StringBuilder.Append(Prefix);
      end;
      if FDecodeSuffixes.TryGetValue(ATokens[I], Suffix) then
        StringBuilder.Append(Suffix);
    end;

    // There is probably a faster implementation of this.
    // Decode isn't currently the focus though.
    if FCleanupTokenizationSpaces then
    begin
      StringBuilder.Replace(' '' ', '''');
      StringBuilder.Replace(' n''t', 'n''t');
      StringBuilder.Replace(' ''m', '''m');
      StringBuilder.Replace(' do not', 'don''t'); // while this seems strange this is what Hugging Face does
      StringBuilder.Replace(' ''s', '''s');
      StringBuilder.Replace(' ''ve', '''ve');
      StringBuilder.Replace(' ''re', '''re');
    end;

    Result := StringBuilder.ToString;
  finally
    StringBuilder.Free;
  end;
end;

function TBertTokenizer.Encode(const AText: string): TArray<Integer>;
var
  Tokens: TList<Integer>;
  FinalList: TList<Integer>;
begin
  CheckVocabulary;
  Tokens := Tokenize(AText);
  try
    FinalList := TList<Integer>.Create;
    try
      FinalList.Add(FClsId);
      FinalList.AddRange(Tokens);
      FinalList.Add(FSepId);
      Result := FinalList.ToArray;
    finally
      FinalList.Free;
    end;
  finally
    Tokens.Free;
  end;
end;

procedure TBertTokenizer.LoadTokenizerJson(const AFileName: string);
var
  Loader: TBertTokenizerJsonLoader;
begin
  Loader := TBertTokenizerJsonLoader.Create;
  try
    Loader.LoadFromFile(AFileName);
    ReadLoaderData(Self, Loader);
  finally
    Loader.Free;
  end;
end;

procedure TBertTokenizer.LoadTokenizerJsonFromStream(Stream: TStream);
var
  Loader: TBertTokenizerJsonLoader;
begin
  Loader := TBertTokenizerJsonLoader.Create;
  try
    Loader.LoadFromStream(Stream);
    ReadLoaderData(Self, Loader);
  finally
    Loader.Free;
  end;
end;

procedure TBertTokenizer.LoadVocabulary(const AFileName: string; ConvertInputToLowercase: Boolean;
  const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
  const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
var
  Loader: TBertTokenizerVocabLoader;
begin
  Loader := TBertTokenizerVocabLoader.Create;
  try
    Loader.LoadFromFile(AFileName, ConvertInputToLowercase, AUnknownToken, AClsToken, ASepToken, APadToken, Normalization);
    ReadLoaderData(Self, Loader);
  finally
    Loader.Free;
  end;
end;

procedure TBertTokenizer.LoadVocabularyFromStream(Stream: TStream; ConvertInputToLowercase: Boolean;
  const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
  const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
var
  Loader: TBertTokenizerVocabLoader;
begin
  Loader := TBertTokenizerVocabLoader.Create;
  try
    Loader.LoadFromStream(Stream, ConvertInputToLowercase, AUnknownToken, AClsToken, ASepToken, APadToken, Normalization);
    ReadLoaderData(Self, Loader);
  finally
    Loader.Free;
  end;
end;

function TBertTokenizer.NormalizeText(const AText: string): string;
begin
  if FConvertInputToLowercase then
    Result := LowerCase(AText)
  else
    Result := AText;
end;

function TBertTokenizer.PreProcessText(const AText: string): TArray<string>;

  function IsPunctuation(cp: Char): Boolean;
  begin
   if ((cp >= '!') and (cp <= '/')) or ((cp >= ':') and (cp <= '@')) or ((cp >= '[') and (cp <= '`')) or ((cp >= '{') and (cp <= '~')) then
     Exit(true);
   Result := cp.IsPunctuation();
  end;

  // This defines a "chinese character" as anything in the CJK Unicode block:
  //   https://en.wikipedia.org/wiki/CJK_Unified_Ideographs_(Unicode_block)
  //
  // Note that the CJK Unicode block is NOT all Japanese and Korean characters,
  // despite its name. The modern Korean Hangul alphabet is a different block,
  // as is Japanese Hiragana and Katakana. Those alphabets are used to write
  // space-separated words, so they are not treated specially and handled
  // like all of the other languages.
  function IsChineseCharacter(cp: Char): Boolean;
  begin
   Result := ((cp >= #$4E00) and (cp <= #$9FFF)) or
     ((cp >= #$3400) and (cp <= #$4DBF)) or
     ((cp >= #$20000) and (cp <= #$2A6DF)) or
     ((cp >= #$2A700) and (cp <= #$2B73F)) or
     ((cp >= #$2B740) and (cp <= #$2B81F)) or
     ((cp >= #$2B820) and (cp <= #$2CEAF)) or
     ((cp >= #$F900) and (cp <= #$FAFF)) or
     ((cp >= #$2F800) and (cp <= #$2FA1F));
  end;

  procedure AddWord(WordList: TList<string>; StartIdx: Integer; Idx: Integer);
  begin
   if Idx = StartIdx then
     Exit;
   WordList.Add(NormalizeText(AText.Substring(StartIdx, Idx - StartIdx)));
  end;

var
  WordList: TList<string>;
  StartIdx, Idx: Integer;
  cp: Char;
begin
  WordList := TList<string>.Create;
  try
    StartIdx := 0;
    Idx := 0;
    while idx < AText.Length do
    begin
      cp := AText[Idx + 1];
      if cp.IsWhiteSpace() then
      begin
        AddWord(WordList, StartIdx, Idx);
        StartIdx := Idx + 1;
      end
      else if IsPunctuation(cp) or IsChineseCharacter(cp) then
      begin
        AddWord(WordList, StartIdx, Idx);
        StartIdx := Idx;
      end;
      Inc(Idx);
    end;

    AddWord(WordList, StartIdx, Idx);

    Result := WordList.ToArray();
  finally
    WordList.Free;
  end;

end;

function TBertTokenizer.Tokenize(const AText: string): TList<Integer>;
var
  Words: TArray<string>;
  Word: string;
begin
  Result := TList<Integer>.Create;

  Words := PreProcessText(AText);
  for Word in Words do
  begin
    TokenizeSubword(Word, Result);
  end;
end;

function TBertTokenizer.TokenizeSubword(const AWord: string; Tokens: TList<Integer>): Integer;

  function DoUnknown: Integer;
  begin
    Tokens.Add(FUnkId);
    Result := 1;
  end;

var
  Prefix, Suffix: string;
  OutId, Id: Integer;
  Remaining: string;
begin
  Result := 0;

  Prefix := AWord;
  Id := -1;

  while (Prefix <> '') do
  begin
    if FPrefixes.TryGetValue(Prefix, OutId) then
    begin
      Id := OutId;
      Break;
    end;
    Prefix := Prefix.Substring(0, Prefix.Length - 1);
  end;

  if Id = -1 then
  begin
    Result := DoUnknown;
    Exit;
  end;

  Tokens.Add(Id);
  Inc(Result);

  Remaining := AWord.Substring(Prefix.Length);

  while Remaining.Length > 0 do
  begin
    Suffix := Remaining;
    Id := -1;

    while Suffix.Length > 0 do
    begin
      if FSuffixes.TryGetValue(Suffix, OutId) then
      begin
        Id := OutId;
        Break;
      end;
      Suffix := Suffix.Substring(0, Suffix.Length - 1);
    end;

    if Id = -1 then
    begin
      Inc(Result, DoUnknown);
    end;

    Tokens.Add(Id);
    Inc(Result);
    Remaining := Remaining.SubString(Suffix.Length);
  end;
end;

end.
