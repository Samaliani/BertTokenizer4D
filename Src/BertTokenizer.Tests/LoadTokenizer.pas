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
    [TestCase('minimal', '../../data/minimal.txt,True')]
    procedure LoadMinimalSuccessfullTokenizers(const APath: string; Lowercase: Boolean);
  end;

implementation

uses
  System.Classes, System.SysUtils,
  System.Threading,
  BertTokenizer;

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

{ TLoadTokenizerTests }

procedure TLoadTokenizerTests.LoadMinimalSuccessfullTokenizers(const APath: string; Lowercase: Boolean);
begin
  DoLoadTokenizer(APath, Lowercase);
  Assert.Pass;
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

