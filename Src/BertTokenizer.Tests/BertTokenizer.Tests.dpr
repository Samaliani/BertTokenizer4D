program BertTokenizer.Tests;

uses
  Vcl.Forms,
  DUnitX.Loggers.GUI.VCL,
  BertTokenizer in '..\BertTokenizer\BertTokenizer.pas',
  TokenizerJson in '..\BertTokenizer\TokenizerJson.pas',
  LoadTokenizer in 'LoadTokenizer.pas',
  Decode in 'Decode.pas',
  BertTokenizer.Json in '..\BertTokenizer\BertTokenizer.Json.pas',
  BertTokenizer.Loader in '..\BertTokenizer\BertTokenizer.Loader.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);
  Application.Run;
end.
