unit BertTokenizer.Loader;

interface

uses
  System.SysUtils,
  System.Classes,
  BertTokenizer,
  System.Generics.Collections;

type
  TBertTokenizerLoader = class
  private
    FPrefixes: TDictionary<string, Integer>;
    FSuffixes: TDictionary<string, Integer>;

    FUnkId, FClsId, FSepId, FPadId: Integer;
    FUnknownToken, FClsToken, FSepToken, FPadToken: string;

    FSuffixPrefix: string;
    FConvertInputToLowercase: Boolean;
    FNormalization : TNormalizationForm; // TODO To Tokenizer??
    FCleanupTokenizationSpaces: Boolean;
  protected
    procedure StartCheck; virtual;
    procedure Initialize; virtual;
    procedure FinalCheck; virtual;
    procedure CleanUpOnException; virtual;
    procedure Process; virtual;
    procedure HandleLine(const ALine: string; TokenId: Integer);

    property UnknownToken: string read FUnknownToken write FUnknownToken;
    property ClsToken: string read FClsToken write FClsToken;
    property SepToken: string read FSepToken write FSepToken;
    property PadToken: string read FPadToken write FPadToken;
  public
    procedure Load;

    property Prefixes: TDictionary<string, Integer> read FPrefixes;
    property Suffixes: TDictionary<string, Integer> read FSuffixes;
    property UnkId: Integer read FUnkId;
    property ClsId: Integer read FClsId;
    property SepId: Integer read FSepId;
    property PadId: Integer read FPadId;
    property SuffixPrefix: string read FSuffixPrefix write FSuffixPrefix;
    property ConvertInputToLowercase: Boolean read FConvertInputToLowercase write FConvertInputToLowercase;
    property Normalization: TNormalizationForm read FNormalization write FNormalization;
    property CleanupTokenizationSpaces: Boolean read FCleanupTokenizationSpaces write FCleanupTokenizationSpaces;
  end;

  TBertTokenizerVocabLoader = class(TBertTokenizerLoader)
  private
    FStream: TStream;
    FTokenIdx: Integer;
  protected
    procedure Initialize; override;
    procedure StartCheck; override;
    procedure Process; override;
  public
    procedure LoadFromFile(const AFileName: string; ConvertInputToLowercase: Boolean; const AUnknownToken: string;
      const AClsToken: string; const ASepToken: string; const APadToken: string; Normalization : TNormalizationForm);
    procedure LoadFromStream(Stream: TStream; ConvertInputToLowercase: Boolean; const AUnknownToken: string;
      const AClsToken: string; const ASepToken: string; const APadToken: string; Normalization : TNormalizationForm);
  end;

implementation

const
  VocabTxtDefaultContinuingSubwordPrefix = '##';

{ TBertTokenizerLoader }

procedure TBertTokenizerLoader.CleanUpOnException;
begin
  FPrefixes.Free;
  FSuffixes.Free;
end;

procedure TBertTokenizerLoader.FinalCheck;
begin
  if FUnkId = -1 then
    raise EInvalidOperation.CreateFmt('Vocabulary does not contain unknown token %s', [FUnknownToken]);
  if FClsId = -1 then
    raise EInvalidOperation.CreateFmt('Vocabulary does not contain cls token %s', [FClsToken]);
  if FSepId = -1 then
    raise EInvalidOperation.CreateFmt('Vocabulary does not contain sep token %s', [FSepToken]);
  if FPadId = -1 then
    raise EInvalidOperation.CreateFmt('Vocabulary does not contain pad token %s', [FPadToken]);
end;

procedure TBertTokenizerLoader.HandleLine(const ALine: string; TokenId: Integer);
begin
  if ALine <> '' then
  begin
    if ALine.StartsWith(FSuffixPrefix) then
      FSuffixes.Add(ALine.Substring(FSuffixPrefix.Length), TokenId)
    else
    begin
      if string.CompareOrdinal(ALine, FUnknownToken) = 0 then
        FUnkId := TokenId
      else if string.CompareOrdinal(ALine, FClsToken) = 0 then
        FClsId := TokenId
      else if string.CompareOrdinal(ALine, FSepToken) = 0 then
        FSepId := TokenId
      else if string.CompareOrdinal(ALine, FPadToken) = 0 then
        FPadId := TokenId;
      FPrefixes.Add(ALine, TokenId);
    end;
  end;
end;

procedure TBertTokenizerLoader.Initialize;
begin
  FPrefixes := TDictionary<string, Integer>.Create;
  FSuffixes := TDictionary<string, Integer>.Create;

  FSuffixPrefix := VocabTxtDefaultContinuingSubwordPrefix;
  FConvertInputToLowercase := True;

  FNormalization := TNormalizationForm.FormD; // TODO ??

  FUnkId := -1;
  FClsId := -1;
  FSepId := -1;
  FPadId := -1;
end;

procedure TBertTokenizerLoader.Load;
begin
  StartCheck;
  Initialize;
  try
    Process;
    FinalCheck;
  except
    on E: Exception do
    begin
      CleanUpOnException;
      raise;
    end;
  end;
end;

procedure TBertTokenizerLoader.Process;
begin
end;

procedure TBertTokenizerLoader.StartCheck;
begin
end;

{ TBertTokenizerVocabLoader }

procedure TBertTokenizerVocabLoader.Initialize;
begin
  inherited;
  FTokenIdx := 0;
end;

procedure TBertTokenizerVocabLoader.LoadFromFile(const AFileName: string; ConvertInputToLowercase: Boolean; const AUnknownToken, AClsToken,
  ASepToken, APadToken: string; Normalization: TNormalizationForm);
var
  AFileStream: TFileStream;
begin
  AFileStream := TFileStream.Create(AFileName, fmOpenRead);
  try
    LoadFromStream(AFileStream, ConvertInputToLowercase, AUnknownToken, AClsToken, ASepToken, APadToken, Normalization);
  finally
    AFileStream.Free;
  end;
end;

procedure TBertTokenizerVocabLoader.LoadFromStream(Stream: TStream; ConvertInputToLowercase: Boolean; const AUnknownToken, AClsToken,
  ASepToken, APadToken: string; Normalization: TNormalizationForm);
begin
  FStream := Stream;
  FConvertInputToLowercase := ConvertInputToLowercase;
  FUnknownToken := AUnknownToken;
  FClsToken := AClsToken;
  FSepToken := ASepToken;
  FPadToken := APadToken;
  FNormalization := Normalization;

  Load;
end;

procedure TBertTokenizerVocabLoader.Process;
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromStream(FStream, TEncoding.UTF8);
    for I := 0 to Lines.Count - 1 do
    begin
      HandleLine(Lines[I], FTokenIdx);
      Inc(FTokenIdx);
    end;
  finally
    Lines.Free;
  end;
end;

procedure TBertTokenizerVocabLoader.StartCheck;
begin
  inherited;
  if FStream = nil then
    raise EArgumentNilException.Create('Stream parameter is nil');
  if FUnknownToken = '' then
    raise EArgumentException.Create('AUnknownToken is not specified');
  if FClsToken = '' then
    raise EArgumentException.Create('AClsToken is not specified');
  if FSepToken = '' then
    raise EArgumentException.Create('ASepToken is not specified');
  if FPadToken = '' then
    raise EArgumentException.Create('APadToken is not specified');
end;


end.
