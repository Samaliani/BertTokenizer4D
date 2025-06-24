unit BertTokenizer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections;

{$SCOPEDENUMS ON}

type
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
    FConvertInputToLowercase: Boolean;
    FDecoderPrefix: string;
    FUnkId, FClsId, FSepId, FPadId: Integer;
    function PreProcessText(const AText: string): TArray<string>;
    function NormalizeText(const AText: string): string;
    function TokenizeSubword(const AWord: string; Tokens: TList<Integer>): Integer;
    function Tokenize(const AText: string): TList<Integer>;
  protected
    function LoadVocabularyFromStreamImpl(Stream: TStream; ConvertInputToLowercase: Boolean; const AUnknownToken: string;
      const AClsToken: string; const ASepToken: string; const APadToken: string; Normalization : TNormalizationForm): ITask;
  public
    destructor Destroy; override;

    procedure LoadVocabulary(const AFileName: string; ConvertInputToLowercase: Boolean;
      const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
      const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
    procedure LoadVocabularyFromStream(Stream: TStream; ConvertInputToLowercase: Boolean;
      const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
      const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);

    function Encode(const AText: string): TArray<Integer>;
  end;

implementation

uses
  System.Character;

type
  TBertTokenizerLoaderStream = class(TTask)

  end;

function TBertTokenizer.LoadVocabularyFromStreamImpl(Stream: TStream; ConvertInputToLowercase: Boolean; const AUnknownToken: string;
  const AClsToken: string; const ASepToken: string; const APadToken: string; Normalization : TNormalizationForm): ITask;

const
  VocabTxtDefaultContinuingSubwordPrefix = '##';

var
  Prefixes, Suffixes: TDictionary<string, Integer>;
  UnkId, ClsId, SepId, PadId: Integer;
  Token: Integer;

  procedure StartCheck;
  begin
    if Stream = nil then
      raise EArgumentNilException.Create('Stream parameter is nil');
    if AUnknownToken = '' then
      raise EArgumentException.Create('AUnknownToken is not specified');
    if AClsToken = '' then
      raise EArgumentException.Create('AClsToken is not specified');
    if ASepToken = '' then
      raise EArgumentException.Create('ASepToken is not specified');
    if APadToken = '' then
      raise EArgumentException.Create('APadToken is not specified');

    if FPrefixes <> nil then
      raise EInvalidOperation.Create('Vocabulary already loaded.');
  end;


  procedure Init;
  begin
    Prefixes := TDictionary<string, Integer>.Create;
    Suffixes := TDictionary<string, Integer>.Create;

    UnkId := -1;
    ClsId := -1;
    SepId := -1;
    PadId := -1;

    Token := 0;
  end;

  procedure HandleLine(const ALine: string);
  begin
    if ALine <> '' then
    begin
      if ALine.StartsWith(VocabTxtDefaultContinuingSubwordPrefix) then
        Suffixes.Add(ALine.Substring(VocabTxtDefaultContinuingSubwordPrefix.Length), Token)
      else if string.CompareOrdinal(ALine, AUnknownToken) = 0 then
        UnkId := Token
      else if string.CompareOrdinal(ALine, AClsToken) = 0 then
        ClsId := Token
      else if string.CompareOrdinal(ALine, ASepToken) = 0 then
        SepId := Token
      else if string.CompareOrdinal(ALine, APadToken) = 0 then
        PadId := Token
      else
        Prefixes.Add(ALine, Token);
    end;
    Inc(Token);
  end;

  procedure ProcessLines;
  var
    Lines: TStringList;
    I: Integer;
  begin
    Token := 0;
    Lines := TStringList.Create;
    try
      Lines.LoadFromStream(Stream, TEncoding.UTF8);
      for I := 0 to Lines.Count - 1 do
        HandleLine(Lines[I]);
    finally
      Lines.Free;
    end;
  end;

  procedure FinalCheck;
  begin
    if UnkId = -1 then
      raise EInvalidOperation.CreateFmt('Vocabulary does not contain unknown token %s', [AUnknownToken]);
    if ClsId = -1 then
      raise EInvalidOperation.CreateFmt('Vocabulary does not contain cls token %s', [AClsToken]);
    if SepId = -1 then
      raise EInvalidOperation.CreateFmt('Vocabulary does not contain sep token %s', [ASepToken]);
    if PadId = -1 then
      raise EInvalidOperation.CreateFmt('Vocabulary does not contain pad token %s', [APadToken]);
  end;

  procedure CleanUpOnException;
  begin
    Prefixes.Free;
    Suffixes.Free;
  end;

  procedure CopyToInstance;
  begin
    FPrefixes := Prefixes;
    FSuffixes := Suffixes;

    FConvertInputToLowercase := ConvertInputToLowercase;
    FDecoderPrefix := VocabTxtDefaultContinuingSubwordPrefix;

    FUnkId := UnkId;
    FClsId := ClsId;
    FSepId := SepId;
    FPadId := PadId;
  end;

begin
  StartCheck;
  Init;
  try
    ProcessLines;
    FinalCheck;
  except
    on E: Exception do
    begin
      CleanUpOnException;
      raise;
    end;
  end;

  CopyToInstance;
end;

{ TBertTokenizer }

destructor TBertTokenizer.Destroy;
begin
  FPrefixes.Free;
  FSuffixes.Free;
  inherited;
end;

function TBertTokenizer.Encode(const AText: string): TArray<Integer>;
var
  Tokens: TList<Integer>;
  FinalList: TList<Integer>;
begin
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

procedure TBertTokenizer.LoadVocabulary(const AFileName: string; ConvertInputToLowercase: Boolean;
  const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
  const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
var
  AFileStream: TFileStream;
begin
  AFileStream := TFileStream.Create(AFileName, fmOpenRead);
  try
    LoadVocabularyFromStream(AFileStream, ConvertInputToLowercase, AUnknownToken, AClsToken, ASepToken, APadToken, Normalization);
  finally
    AFileStream.Free;
  end;
end;

procedure TBertTokenizer.LoadVocabularyFromStream(Stream: TStream; ConvertInputToLowercase: Boolean;
  const AUnknownToken: string = '[UNK]'; const AClsToken: string = '[CLS]'; const ASepToken: string = '[SEP]';
  const APadToken: string = '[PAD]'; Normalization : TNormalizationForm = TNormalizationForm.FormD);
begin
  LoadVocabularyFromStreamImpl(Stream, ConvertInputToLowercase, '[UNK]', '[CLS]', '[SEP]', '[PAD]', TNormalizationForm.FormD);
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
