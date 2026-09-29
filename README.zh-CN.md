# CRC32

Racket 的 CRC32（IEEE 802.3）校验和实现。支持对字节串、多种编码的字符串以及输入端口计算 CRC32 校验和，同时提供用于增量计算的低级 API。

![Racket](https://img.shields.io/badge/Racket-9F1D20?logo=racket&logoColor=white) [![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[English](README.md) · **中文**

## 功能特性

- **高级 API** —— 对字节串、UTF-8 / Latin-1 / 本地编码字符串以及输入端口计算 CRC32
- **增量计算** —— 低级 API 支持逐字节更新累加器并最终生成校验和
- **高性能** —— slicing-by-8 内核：字节串与输入端口吞吐约 1.2 GB/s（Racket 9、Apple M 系列芯片实测）
- **测试覆盖全面** —— 标准测试向量、边界情况、ASCII/UTF-8（中日韩、emoji、西里尔字母、阿拉伯字母、希腊字母）、大数据以及二进制文件头

## 环境要求

| 依赖 | 用途 / 版本 |
|------|------------|
| Racket | 7.0 或更高版本 |

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/turinglambdaai/crc32.git
cd crc32
```

### 2. 安装

```bash
raco pkg install crc32
```

### 3. 使用

```racket
#lang racket
(require crc32)

; 计算字节串的 CRC32
(crc32-bytes #"hello world")

; 计算 UTF-8 编码字符串的 CRC32
(crc32-string/utf8 "hello world")

; 从输入端口计算 CRC32
(crc32-input-port (open-input-file "myfile.txt"))
```

## API

### 高级 API

| 函数 | 说明 |
|------|------|
| `(crc32-bytes bs)` | 计算字节串的 CRC32 |
| `(crc32-string/utf8 str)` | 计算 UTF-8 编码字符串的 CRC32 |
| `(crc32-string/latin-1 str)` | 计算 Latin-1 编码字符串的 CRC32 |
| `(crc32-string/locale str)` | 计算本地编码字符串的 CRC32 |
| `(crc32-input-port [in])` | 从输入端口计算 CRC32 |

所有函数均返回 `exact-nonnegative-integer?` 类型的值。

### 低级 API（增量计算）

```racket
; 增量计算
(define acc crc32-initial-value)
(set! acc (crc32-update acc 104)) ; 'h'
(set! acc (crc32-update acc 101)) ; 'e'
(set! acc (crc32-update acc 108)) ; 'l'
(set! acc (crc32-update acc 108)) ; 'l'
(set! acc (crc32-update acc 111)) ; 'o'
(crc32-finalize acc)
; => 与 (crc32-bytes #"hello") 结果相同
```

| 函数 / 值 | 说明 |
|-----------|------|
| `crc32-initial-value` | CRC32 累加器初始值（`#xFFFFFFFF`） |
| `(crc32-update acc byte)` | 用单个字节更新累加器 |
| `(crc32-finalize acc)` | 应用最终 XOR 得到校验和 |

## 开发

```bash
raco test main.rkt
```

测试套件覆盖标准测试向量、边界情况、重复模式、递增序列、ASCII 字符串、UTF-8 字符串（包括中日韩文字、emoji、西里尔字母、阿拉伯字母和希腊字母）、大数据、二进制文件格式头部、增量计算以及输入端口功能。

## 许可证

基于 [MIT License](LICENSE) 开源。
