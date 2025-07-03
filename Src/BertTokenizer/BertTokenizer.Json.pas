unit BertTokenizer.Json;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.JSON.Serializers,
  System.JSON.Converters,
  BertTokenizer.Loader;

type
  TTokenizerJson = class;

  TBertTokenizerJsonLoader = class(TBertTokenizerLoader)
  private
    FTokenizerJson: TTokenizerJson;
  protected
    procedure StartCheck; override;
    procedure Process; override;
  public
    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromStream(Stream: TStream);
  end;

  TTokenizerJson = class
  public type

    // https://huggingface.co/docs/tokenizers/python/latest/api/reference.html#tokenizers.AddedToken
    TAddedToken = class
    private
      [JsonName('id')]
      FId: Integer;
      [JsonName('content')]
      FContent: string;
      [JsonName('single_word')]
      FSingleWord: Boolean;
      [JsonName('lstrip')]
      FLStrip: Boolean;
      [JsonName('rstrip')]
      FRStrip: Boolean;
      [JsonName('normalized')]
      FNormalized: Boolean;
    public
      property Id: Integer read FId;
      property Content: string read FContent;
      property SingleWord: Boolean read FSingleWord;
      property LStrip: Boolean read FLStrip;
      property RStrip: Boolean read FRStrip;
      property Normalized: Boolean read FNormalized;
    end;

    TNormalizerSection = class
    private
      [JsonName('type')]
      FType: string;
      [JsonName('clean_text')]
      FCleanText: Boolean;
      [JsonName('handle_chinese_chars')]
      FHandleChineseChars: Boolean;
      [JsonName('strip_accents')] // ?? Nillable in .Net
      FStripAccents: Boolean;
      [JsonName('lowercase')]
      FLowercase: Boolean;
    public
      constructor Create;

      property _Type: string read FType;
      property CleanText: Boolean read FCleanText;
      property HandleChineseChars: Boolean read FHandleChineseChars
        write FHandleChineseChars;
      property StripAccents: Boolean read FStripAccents;
      property Lowercase: Boolean read FLowercase write FLowercase;
    end;

    TPreTokenizerSection = class
    private
      [JsonName('type')]
      FType: string;
    public
      property _Type: string read FType;
    end;

    TPostProcessorSection = class
    public type
      TSpecialTokenDetails = class
      private
        // E.g. [CLS] or [SEP].
        [JsonName('id')]
        FId: string;
      public
        property Id: string read FId;
      end;

      TSpecialTokensConverter = class(TJsonStringDictionaryConverter<TSpecialTokenDetails>);

    private
      [JsonName('type')]
      FType: string;
      [JsonName('special_tokens'), JsonConverter(TSpecialTokensConverter)]
      FSpecialTokens: TDictionary<string, TSpecialTokenDetails>;
    public
      destructor Destroy; override;
      property _Type: string read FType;
      property SpecialTokens: TDictionary<string, TSpecialTokenDetails> read FSpecialTokens;
    end;

    TModelSection = class
    public type
      TVocabConverter = class(TJsonStringDictionaryConverter<Integer>);

    private
      [JsonName('type')]
      FType: string;
      [JsonName('unk_token')]
      FUnkToken: string;
      [JsonName('continuing_subword_prefix')]
      FContinuingSubwordPrefix: string;
      [JsonName('vocab'), JsonConverter(TVocabConverter)]
      FVocab: TDictionary<string, Integer>;
    public
      destructor Destroy; override;

      property _Type: string read FType;
      property UnkToken: string read FUnkToken;
      property ContinuingSubwordPrefix: string read FContinuingSubwordPrefix;
      property Vocab: TDictionary<string, Integer> read FVocab;
    end;

    TDecoderSection = class
    private
      [JsonName('type')]
      FType: string;
      [JsonName('prefix')]
      FPrefix: string;
      [JsonName('cleanup')]
      FCleanup: Boolean;
    public
      property _Type: string read FType;
      property Prefix: string read FPrefix;
      property Cleanup: Boolean read FCleanup;
    end;

  private
    [JsonName('version')]
    FVersion: string;
    [JsonName('added_tokens')]
    FAddedTokens: TArray<TAddedToken>;
    [JsonName('normalizer')]
    FNormalizer: TNormalizerSection;
    [JsonName('pre_tokenizer')]
    FPreTokenizer: TPreTokenizerSection;
    [JsonName('post_processor')]
    FPostProcessor: TPostProcessorSection;
    [JsonName('model')]
    FModel: TModelSection;
    [JsonName('decoder')]
    FDecoder: TDecoderSection;
  public
    destructor Destroy; override;

    property Version: string read FVersion;
    property AddedTokens: TArray<TAddedToken> read FAddedTokens;
    property Normalizer: TNormalizerSection read FNormalizer;
    property PreTokenizer: TPreTokenizerSection read FPreTokenizer;
    property PostProcessor: TPostProcessorSection read FPostProcessor;
    property Model: TModelSection read FModel;
    property Decoder: TDecoderSection read FDecoder;
  end;


implementation

uses
  System.SysUtils,
  System.JSON.Readers,
  BertTokenizer;

{ TTokenizerJson }

destructor TTokenizerJson.Destroy;
var
  AddedToken: TAddedToken;
begin
  for AddedToken in FAddedTokens do
    AddedToken.Free;
  FNormalizer.Free;
  FPreTokenizer.Free;
  FPostProcessor.Free;
  FModel.Free;
  FDecoder.Free;
  inherited;
end;

{ TTokenizerJson.TNormalizerSection }

constructor TTokenizerJson.TNormalizerSection.Create;
begin
  inherited Create;
  FCleanText := True;
  FHandleChineseChars := True;
  FLowercase := True;
end;

{ TTokenizerJson.TModelSection }

destructor TTokenizerJson.TModelSection.Destroy;
begin
  FVocab.Free;
  inherited;
end;

{ TTokenizerJson.TPostProcessorSection }

destructor TTokenizerJson.TPostProcessorSection.Destroy;
var
  Pair: TPair<string, TSpecialTokenDetails>;
begin
  for Pair in FSpecialTokens do
    Pair.Value.Free;
  FSpecialTokens.Free;
  inherited;
end;

{ TBertTokenizerJsonLoader }

procedure TBertTokenizerJsonLoader.LoadFromFile(const AFileName: string);
var
  AFileStream: TFileStream;
begin
  AFileStream := TFileStream.Create(AFileName, fmOpenRead);
  try
    LoadFromStream(AFileStream);
  finally
    AFileStream.Free;
  end;
end;

procedure TBertTokenizerJsonLoader.LoadFromStream(Stream: TStream);
var
  StreamReader: TStreamReader;
  JsonReader: TJsonTextReader;
  Serializer: TJsonSerializer;
begin
  StreamReader := TStreamReader.Create(Stream, TEncoding.UTF8);
  try
    JsonReader := TJsonTextReader.Create(StreamReader);
    try
      Serializer := TJsonSerializer.Create();
      try
        FTokenizerJson := Serializer.Deserialize<TTokenizerJson>(JsonReader);
        try
          Load;
        finally
          FTokenizerJson.Free;
        end;
      finally
        Serializer.Free;
      end;
    finally
      JsonReader.Free;
    end;
  finally
    StreamReader.Free;
  end;
end;

procedure TBertTokenizerJsonLoader.Process;
var
  TokenPair: TPair<string, Integer>;
  AddedToken: TTokenizerJson.TAddedToken;
  Decoder: TTokenizerJson.TDecoderSection;
begin
  SuffixPrefix := FTokenizerJson.Model.ContinuingSubwordPrefix; // e.g. "##"
  Normalization := TNormalizationForm.FormD; // bert uses FormD per default

  ClsToken := FTokenizerJson.PostProcessor.SpecialTokens['[CLS]'].Id;
  SepToken := FTokenizerJson.PostProcessor.SpecialTokens['[SEP]'].Id;
  UnknownToken := FTokenizerJson.Model.UnkToken;
  PadToken := '[PAD]'; // In e.g. https://huggingface.co/bert-base-uncased/raw/main/tokenizer.json there is no nice way to detect this.

  for TokenPair in FTokenizerJson.Model.Vocab do
    HandleLine(TokenPair.Key, TokenPair.Value);

  for AddedToken in FTokenizerJson.AddedTokens do
  begin
    // We ignore LStrip and RStrip as FastBertTokenizer always pre-tokenizes on whitespace,
    // true and false would result in the same behavior.
    if AddedToken.SingleWord then
      raise EArgumentException.Create('FastBertTokenizer only supports added tokens with single_word=false. The given tokenizer.json does however contain an added token {addedToken.Content} = {addedToken.Id} with single_word = true.');

    // This does not seem to be required in all cases, e.g. [CLS] with bert-base-uncased, but required in others, e.g. 21.22 with issue #100 tokenizer.
    Prefixes.AddOrSetValue(AddedToken.Content, AddedToken.Id);
  end;

  ConvertInputToLowercase := FTokenizerJson.Normalizer.Lowercase;
  // TODO check _stripAccents = tok.Normalizer.StripAccents ?? _lowercaseInput;
  CleanupTokenizationSpaces := True;
  Decoder := FTokenizerJson.Decoder;
  if Decoder <> nil then
  begin
    if Decoder.Prefix <> '' then
      SuffixPrefix := Decoder.Prefix;
    CleanupTokenizationSpaces := Decoder.Cleanup;
  end;
end;

procedure TBertTokenizerJsonLoader.StartCheck;
begin
  if FTokenizerJson.Version <> '1.0' then
    raise EArgumentException.CreateFmt('The confiuguration specifies version %s, but currently only version 1.0 is supported.', [FTokenizerJson.Version]);

  if (FTokenizerJson.Model._Type <> 'WordPiece') and (FTokenizerJson.Model._Type <> '') then //.Net && tok.Model.Type is not null
    raise EArgumentException.CreateFmt('The configuration specifies model type %s, but currently only WordPiece is supported.', [FTokenizerJson.Model._Type]);

  if FTokenizerJson.Normalizer._Type <> 'BertNormalizer'  then
    raise EArgumentException.CreateFmt('The configuration specifies normalizer type %s, but currently only BertNormalizer is supported.', [FTokenizerJson.Normalizer._Type]);

  if FTokenizerJson.PreTokenizer._Type <> 'BertPreTokenizer'  then
    raise EArgumentException.CreateFmt('The configuration specifies pre-tokenizer type %s, but currently only BertPreTokenizer is supported.', [FTokenizerJson.PreTokenizer._Type]);

  if FTokenizerJson.Normalizer.HandleChineseChars = False  then
    raise EArgumentException.Create('The configuration specifies Normalizer.HandleChineseChars = false, but currently only HandleChineseChars = true is supported.');

  if not FTokenizerJson.Normalizer.CleanText then
    raise EArgumentException.Create('The configuration specifies Normalizer.CleanText = false, but currently only CleanText = true is supported.');
end;

end.