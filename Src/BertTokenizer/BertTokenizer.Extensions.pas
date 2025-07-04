unit BertTokenizer.Extensions;

interface

uses
  BertTokenizer;

type
  TBertTokenizerExtensions = class helper for TBertTokenizer
    procedure LoadFromHuggingFace(const AHuggingFaceRepo: string);
  end;



implementation

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient;

{ TBertTokenizerExtensions }

procedure TBertTokenizerExtensions.LoadFromHuggingFace(const AHuggingFaceRepo: string);
var
  Url: string;
  AResponseStream: TMemoryStream;
  HttpClient: THTTPClient;
  UserAgent: TNameValuePair;
  HttpResponse: IHTTPResponse;
begin
  Url := Format('https://huggingface.co/%s/resolve/main/tokenizer.json?download=true', [AHuggingFaceRepo]);
  AResponseStream := TMemoryStream.Create;
  try
    HttpClient := THTTPClient.Create;
    try
      UserAgent.Name := 'User-Agent';
      UserAgent.Value := 'BertTokenizer4D';
      HttpResponse := HttpClient.Get(Url, AResponseStream, [UserAgent]);
    finally
      HttpClient.Free;
    end;

   // ENetHTTPException ???
    if HttpResponse.StatusCode = 200 then
      Self.LoadTokenizerJsonFromStream(AResponseStream);
  finally
    AResponseStream.Free;
  end;
end;

end.
