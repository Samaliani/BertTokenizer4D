program BertTokenizer.Tests;

uses
  Vcl.Forms,
  DUnitX.Loggers.GUI.VCL,// in 'DUnitX.Loggers.GUI.VCL.pas' {GUIVCLTestRunner},
  BertTokenizer in '..\BertTokenizer\BertTokenizer.pas',
  LoadTokenizer in 'LoadTokenizer.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);
  Application.Run;
end.
