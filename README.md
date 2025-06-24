# BertTokenizer4D

A Delphi implementation of the BERT tokenizer — `TBertTokenizer` — inspired by the .NET `BertTokenizer`. It supports WordPiece tokenization and converts text into token ID sequences ready for input into BERT models via ONNX.

## 📦 Features

- Load vocabulary from file or stream
- Converts raw text into token ID arrays
- Compatible with [TONNXRuntime](https://github.com/hshatti/TONNXRuntime) for inference

## 📁 Project Structure

- Main unit: `Src/BertTokenizer/BertTokenizer.pas`
- Core class: `TBertTokenizer`

## 🚀 Quick Start

```pascal
uses
  BertTokenizer, System.Classes;

procedure LoadTokenizerAndEncode(const APath: string);
begin
  var Tokenizer := TBertTokenizer.Create;
  try 
    Tokenizer.LoadVocabulary(APath);
    var Tokens := Tokenizer.Encode('Hello, world!');
    // TokenIds can now be passed to a model using TONNXRuntime
  finally
    Tokenizer.Free;
  end;
end;
````

## 🧠 Public API

| Method                                  | Description                                            |
| --------------------------------------- | ------------------------------------------------------ |
| `LoadVocabulary(FileName, ...)`         | Loads vocabulary from a file                           |
| `LoadVocabularyFromStream(Stream, ...)` | Loads vocabulary from a stream                         |
| `Encode(Text)`                          | Tokenizes input text and returns an array of token IDs |

All methods allow customization of tokens (`[UNK]`, `[CLS]`, `[SEP]`, `[PAD]`) and normalization settings.

## ✅ Dependencies

* **Delphi 10.0+**
* No external dependencies required for core functionality
* Optional test support via [`DUnitX`](https://github.com/VSoftTechnologies/DUnitX)

## 🤖 BERT + ONNX Integration

The output of `Encode` is compatible with ONNX BERT models. You can use [`TONNXRuntime`](https://github.com/hshatti/TONNXRuntime) to run inference on tokenized input (`input_ids`).

## 📄 License

MIT License — free to use, modify, and distribute.

---


