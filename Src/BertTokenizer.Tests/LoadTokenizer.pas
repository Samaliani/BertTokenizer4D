unit LoadTokenizer;

interface

uses
  DUnitX.TestFramework;

type
  {$M+}
  [TestFixture('LoadTokenizer')]
  TLoadTokenizerTests = class
  public
    [Test]
    [TestCase('baai-bge-small-en', '../../../../data/baai-bge-small-en/tokenizer.json')]
    [TestCase('bert-base-chinese', '../../../../data/bert-base-chinese/tokenizer.json')]
    [TestCase('bert-base-multilingual-cased', '../../../../data/bert-base-multilingual-cased/tokenizer.json')]
    [TestCase('bert-base-uncased', '../../../../data/bert-base-uncased/tokenizer.json')]
    procedure LoadTokenizerFromJson(const APath: string);

    [Test]
    [TestCase('baai-bge-small-en', '../../../../data/baai-bge-small-en/vocab.txt,True')]
    [TestCase('bert-base-chinese', '../../../../data/bert-base-chinese/vocab.txt,True')]
    [TestCase('bert-base-multilingual-cased', '../../../../data/bert-base-multilingual-cased/vocab.txt,True')]
    [TestCase('bert-base-uncased', '../../../../data/bert-base-uncased/vocab.txt,True')]
    procedure LoadTokenizerFromVocabAsync(const APath: string; Lowercase: Boolean);

    [Test]
    [TestCase('baai-bge-small-en', '../../../../data/baai-bge-small-en/vocab.txt,True')]
    [TestCase('bert-base-chinese', '../../../../data/bert-base-chinese/vocab.txt,True')]
    [TestCase('bert-base-multilingual-cased', '../../../../data/bert-base-multilingual-cased/vocab.txt,True')]
    [TestCase('bert-base-uncased', '../../../../data/bert-base-uncased/vocab.txt,True')]
    procedure LoadTokenizerFromVocabSync(const APath: string; Lowercase: Boolean);

    [Test]
    [TestCase('invalid-no-cls', '../../data/invalid/no-cls.txt,True')]
    [TestCase('invalid-no-sep', '../../data/invalid/no-sep.txt,True')]
    [TestCase('invalid-no-pad', '../../data/invalid/no-pad.txt,True')]
    [TestCase('invalid-no-unk', '../../data/invalid/no-unk.txt,True')]
    procedure LoadTokenizerFromInvalidVocabTxt(const APath: string; Lowercase: Boolean);

    [Test]
    [TestCase('wrong-version', '../../data/invalid/wrong-version.json')]
    [TestCase('wrong-model-type', '../../data/invalid/wrong-model-type.json')]
    [TestCase('wrong-normalizer', '../../data/invalid/wrong-normalizer.json')]
    [TestCase('wrong-pretokenizer', '../../data/invalid/wrong-pretokenizer.json')]
    [TestCase('dont-handle-chinese-chars', '../../data/invalid/dont-handle-chinese-chars.json')]
    [TestCase('dont-clean-text', '../../data/invalid/dont-clean-text.json')]
    [TestCase('with-single-word-added-token', '../../data/invalid/with-single-word-added-token.json')]
    procedure LoadTokenizerFromInvalidJson(const APath: string);

    [Test]
    [TestCase('bert-base-uncased', 'bert-base-uncased')]
    procedure LoadFromHuggingFace(const AHuggingFaceRepo: string);

    [Test]
    procedure LoadMinimalSuccessfullTokenizers(const APath: string; Lowercase: Boolean);

    [Test]
    procedure CantWorkWithoutVocab();

    [Test]
    procedure ArgumentExceptions();
  end;

implementation

uses
  System.Classes, System.SysUtils,
  System.Threading,
  BertTokenizer,
  BertTokenizer.Extensions;

procedure DoLoadTokenizer(const APath: string; Lowercase: Boolean);
var
  Stream: TStream;
  Tokenizer: TBertTokenizer;
begin
  Stream := TFileStream.Create(APath, fmOpenRead);
  try
    Tokenizer := TBertTokenizer.Create;
    try
      Tokenizer.LoadVocabularyFromStream(Stream, Lowercase);
    finally
      Tokenizer.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure DoLoadTokenizerJson(const APath: string);
var
  Stream: TStream;
  Tokenizer: TBertTokenizer;
begin
  Stream := TFileStream.Create(APath, fmOpenRead);
  try
    Tokenizer := TBertTokenizer.Create;
    try
      Tokenizer.LoadTokenizerJsonFromStream(Stream);
    finally
      Tokenizer.Free;
    end;
  finally
    Stream.Free;
  end;
end;

{ TLoadTokenizerTests }

procedure TLoadTokenizerTests.ArgumentExceptions;
var
  Tokenizer: TBertTokenizer;
begin
  Tokenizer := TBertTokenizer.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        tokenizer.LoadTokenizerJsonFromStream(nil);;
      end,
      EArgumentException
    );

    Assert.WillRaise(
      procedure
      begin
        Tokenizer.LoadVocabulary('../../../../data/bert-base-uncased/vocab.txt', True, '');
      end,
      EArgumentException
    );

    Assert.WillRaise(
      procedure
      begin
        Tokenizer.LoadVocabulary('../../../../data/bert-base-uncased/vocab.txt', True, '[UNK]', '');
      end,
      EArgumentException
    );

     Assert.WillRaise(
      procedure
      begin
        Tokenizer.LoadVocabulary('../../../../data/bert-base-uncased/vocab.txt', True, '[UNK]', '[CLS]', '');
      end,
      EArgumentException
    );

    Assert.WillRaise(
      procedure
      begin
        Tokenizer.LoadVocabulary('../../../../data/bert-base-uncased/vocab.txt', True, '[UNK]', '[CLS]', '[SEP]',  '');
      end,
      EArgumentException
    );

  finally
    Tokenizer.Free;
  end;
end;

procedure TLoadTokenizerTests.CantWorkWithoutVocab;
var
  Tokenizer: TBertTokenizer;
begin
  Tokenizer := TBertTokenizer.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        Tokenizer.Encode('Lorem ipsum dolor sit amet.');
      end,
      ETokenizerException
    );

    Assert.WillRaise(
      procedure
      begin
        Tokenizer.Decode([0, 1, 2, 3]);
      end,
      ETokenizerException
    );

  finally
    Tokenizer.Free;
  end;
end;

procedure TLoadTokenizerTests.LoadFromHuggingFace(const AHuggingFaceRepo: string);
var
  Tokenizer: TBertTokenizer;
begin
  Tokenizer := TBertTokenizer.Create;
  try
    Tokenizer.LoadFromHuggingFace(AHuggingFaceRepo);
  finally
    Tokenizer.Free;
  end;
  Assert.Pass;
end;

procedure TLoadTokenizerTests.LoadMinimalSuccessfullTokenizers(const APath: string; Lowercase: Boolean);
begin
  DoLoadTokenizer('../../data/minimal.txt', True);
  DoLoadTokenizerJson('../../data/minimal.json');
  DoLoadTokenizerJson('../../data/dont-strip-accents.json');
  DoLoadTokenizerJson('../../data/with-empty-token.json');
  Assert.Pass;
end;

procedure TLoadTokenizerTests.LoadTokenizerFromInvalidJson(const APath: string);
begin
  Assert.WillRaise(
    procedure
    begin
      DoLoadTokenizerJson(APath);
    end,
    EArgumentException
  );
end;

procedure TLoadTokenizerTests.LoadTokenizerFromInvalidVocabTxt(const APath: string; Lowercase: Boolean);
begin
  Assert.WillRaise(
    procedure
    begin
      DoLoadTokenizer(APath, Lowercase);
    end,
    EInvalidOperation
  );
end;

procedure TLoadTokenizerTests.LoadTokenizerFromJson(const APath: string);
begin
  DoLoadTokenizerJson(APath);
  Assert.Pass;
end;

procedure TLoadTokenizerTests.LoadTokenizerFromVocabAsync(const APath: string; Lowercase: Boolean);
var
  Tokenizer: TBertTokenizer;
  Task: ITask;
begin
  Tokenizer := TBertTokenizer.Create;
  try
    Task := TTask.Run(procedure
    begin
      Tokenizer.LoadVocabulary(APath, Lowercase)
    end);
    Task.Wait();
  finally
    Tokenizer.Free;
  end;
  Assert.IsTrue(Task.Status = TTaskStatus.Completed);
end;

procedure TLoadTokenizerTests.LoadTokenizerFromVocabSync(const APath: string; Lowercase: Boolean);
begin
  DoLoadTokenizer(APath, Lowercase);
  Assert.Pass;
end;

initialization
  //Register the test fixtures
  TDUnitX.RegisterTestFixture(TLoadTokenizerTests);

end.

