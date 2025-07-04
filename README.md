# BertTokenizer4D

A Delphi implementation of the BERT tokenizer — `TBertTokenizer` — inspired by the .NET [`FastBertTokenizer`](https://github.com/georg-jung/FastBertTokenizer). It supports WordPiece tokenization and converts text into token ID sequences ready for input into BERT models via ONNX.

## 📦 Features

* Load vocabulary from file (`vocab.txt`) or stream
* Load tokenizer configuration from Hugging Face (`tokenizer.json`)
* Converts raw text into token ID arrays
* Decodes token IDs back into readable text
* Compatible with [TONNXRuntime](https://github.com/hshatti/TONNXRuntime) for ONNX inference

## 📁 Project Structure

* Main unit: `Src/BertTokenizer/BertTokenizer.pas`
* Core class: `TBertTokenizer`

## 🚀 Quick Start

```pascal
uses
  BertTokenizer, BertTokenizer.Extensions;

procedure LoadTokenizerAndEncode(const APath: string);
begin
  var Tokenizer := TBertTokenizer.Create;
  try 
    Tokenizer.LoadFromHuggingFace('bge-micro-v2');
    var Tokens := Tokenizer.Encode('Hello, world!');
    // TokenIds can now be passed to a model using TONNXRuntime
  finally
    Tokenizer.Free;
  end;
end;
```

## 🧠 Public API

| Method                                  | Description                                            |
| --------------------------------------- | ------------------------------------------------------ |
| `LoadVocabulary(FileName, ...)`         | Loads vocabulary from a `vocab.txt` file               |
| `LoadVocabularyFromStream(Stream, ...)` | Loads vocabulary from a stream                         |
| `LoadTokenizerJson(FileName)`           | Loads tokenizer from a Hugging Face `tokenizer.json`   |
| `LoadTokenizerJsonFromStream(Stream)`   | Loads tokenizer from a JSON stream                     |
| `Encode(Text)`                          | Tokenizes input text and returns an array of token IDs |
| `Decode(Tokens)`                        | Decodes an array of token IDs back to text             |
| --------------------------------------- | ------------------------------------------------------ |
| uses BertTokenizer.Extensions           |                                                        |
| `LoadFromHuggingFace(HuggingFaceRepo)`  | Loads tokenizer from Hugging Face repo by name         |

### ✅ Supported Tokenizer Formats

* **`vocab.txt`** — standard BERT vocabulary file
* **`tokenizer.json`** — Hugging Face tokenizer format (WordPiece-based)

## ✅ Dependencies

* **Delphi 10.2 Tokyo+**
* No external dependencies required for core functionality
* Optional test suite using [`DUnitX`](https://github.com/VSoftTechnologies/DUnitX)

### 🧪 Test Coverage

This project includes unit tests using `DUnitX`.

## 🤖 BERT + ONNX Integration

The output of `Encode` is compatible with ONNX BERT models. You can use [`TONNXRuntime`](https://github.com/hshatti/TONNXRuntime) to run inference on tokenized input (`input_ids`).

## 📄 License

MIT License — free to use, modify, and distribute.
