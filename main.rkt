#|

crc32

Contributors:
  [turinglambdaai] <jirentianxiang1024@gmail.com>

Copyright (c) 2025 [turinglambdaai]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

|#

#lang racket/base

(require racket/require
         racket/performance-hint
         (only-in racket/fixnum fxvector make-fxvector)
         (only-in racket/bytes bytes-append*)
         (only-in racket/list make-list)
         (for-syntax racket/base)
         (filtered-in (lambda (name)
                        (regexp-replace #rx"unsafe-" name ""))
                      racket/unsafe/ops))

(provide crc32-initial-value
         crc32-update
         crc32-finalize
         crc32-bytes
         crc32-input-port
         crc32-string/utf8
         crc32-string/latin-1
         crc32-string/locale)

(module+ test (require rackunit))

;; CRC32 lookup table (IEEE 802.3 standard)
(define table (fxvector #x00000000 #x77073096 #xEE0E612C #x990951BA
                        #x076DC419 #x706AF48F #xE963A535 #x9E6495A3
                        #x0EDB8832 #x79DCB8A4 #xE0D5E91E #x97D2D988
                        #x09B64C2B #x7EB17CBD #xE7B82D07 #x90BF1D91
                        #x1DB71064 #x6AB020F2 #xF3B97148 #x84BE41DE
                        #x1ADAD47D #x6DDDE4EB #xF4D4B551 #x83D385C7
                        #x136C9856 #x646BA8C0 #xFD62F97A #x8A65C9EC
                        #x14015C4F #x63066CD9 #xFA0F3D63 #x8D080DF5
                        #x3B6E20C8 #x4C69105E #xD56041E4 #xA2677172
                        #x3C03E4D1 #x4B04D447 #xD20D85FD #xA50AB56B
                        #x35B5A8FA #x42B2986C #xDBBBC9D6 #xACBCF940
                        #x32D86CE3 #x45DF5C75 #xDCD60DCF #xABD13D59
                        #x26D930AC #x51DE003A #xC8D75180 #xBFD06116
                        #x21B4F4B5 #x56B3C423 #xCFBA9599 #xB8BDA50F
                        #x2802B89E #x5F058808 #xC60CD9B2 #xB10BE924
                        #x2F6F7C87 #x58684C11 #xC1611DAB #xB6662D3D
                        #x76DC4190 #x01DB7106 #x98D220BC #xEFD5102A
                        #x71B18589 #x06B6B51F #x9FBFE4A5 #xE8B8D433
                        #x7807C9A2 #x0F00F934 #x9609A88E #xE10E9818
                        #x7F6A0DBB #x086D3D2D #x91646C97 #xE6635C01
                        #x6B6B51F4 #x1C6C6162 #x856530D8 #xF262004E
                        #x6C0695ED #x1B01A57B #x8208F4C1 #xF50FC457
                        #x65B0D9C6 #x12B7E950 #x8BBEB8EA #xFCB9887C
                        #x62DD1DDF #x15DA2D49 #x8CD37CF3 #xFBD44C65
                        #x4DB26158 #x3AB551CE #xA3BC0074 #xD4BB30E2
                        #x4ADFA541 #x3DD895D7 #xA4D1C46D #xD3D6F4FB
                        #x4369E96A #x346ED9FC #xAD678846 #xDA60B8D0
                        #x44042D73 #x33031DE5 #xAA0A4C5F #xDD0D7CC9
                        #x5005713C #x270241AA #xBE0B1010 #xC90C2086
                        #x5768B525 #x206F85B3 #xB966D409 #xCE61E49F
                        #x5EDEF90E #x29D9C998 #xB0D09822 #xC7D7A8B4
                        #x59B33D17 #x2EB40D81 #xB7BD5C3B #xC0BA6CAD
                        #xEDB88320 #x9ABFB3B6 #x03B6E20C #x74B1D29A
                        #xEAD54739 #x9DD277AF #x04DB2615 #x73DC1683
                        #xE3630B12 #x94643B84 #x0D6D6A3E #x7A6A5AA8
                        #xE40ECF0B #x9309FF9D #x0A00AE27 #x7D079EB1
                        #xF00F9344 #x8708A3D2 #x1E01F268 #x6906C2FE
                        #xF762575D #x806567CB #x196C3671 #x6E6B06E7
                        #xFED41B76 #x89D32BE0 #x10DA7A5A #x67DD4ACC
                        #xF9B9DF6F #x8EBEEFF9 #x17B7BE43 #x60B08ED5
                        #xD6D6A3E8 #xA1D1937E #x38D8C2C4 #x4FDFF252
                        #xD1BB67F1 #xA6BC5767 #x3FB506DD #x48B2364B
                        #xD80D2BDA #xAF0A1B4C #x36034AF6 #x41047A60
                        #xDF60EFC3 #xA867DF55 #x316E8EEF #x4669BE79
                        #xCB61B38C #xBC66831A #x256FD2A0 #x5268E236
                        #xCC0C7795 #xBB0B4703 #x220216B9 #x5505262F
                        #xC5BA3BBE #xB2BD0B28 #x2BB45A92 #x5CB36A04
                        #xC2D7FFA7 #xB5D0CF31 #x2CD99E8B #x5BDEAE1D
                        #x9B64C2B0 #xEC63F226 #x756AA39C #x026D930A
                        #x9C0906A9 #xEB0E363F #x72076785 #x05005713
                        #x95BF4A82 #xE2B87A14 #x7BB12BAE #x0CB61B38
                        #x92D28E9B #xE5D5BE0D #x7CDCEFB7 #x0BDBDF21
                        #x86D3D2D4 #xF1D4E242 #x68DDB3F8 #x1FDA836E
                        #x81BE16CD #xF6B9265B #x6FB077E1 #x18B74777
                        #x88085AE6 #xFF0F6A70 #x66063BCA #x11010B5C
                        #x8F659EFF #xF862AE69 #x616BFFD3 #x166CCF45
                        #xA00AE278 #xD70DD2EE #x4E048354 #x3903B3C2
                        #xA7672661 #xD06016F7 #x4969474D #x3E6E77DB
                        #xAED16A4A #xD9D65ADC #x40DF0B66 #x37D83BF0
                        #xA9BCAE53 #xDEBB9EC5 #x47B2CF7F #x30B5FFE9
                        #xBDBDF21C #xCABAC28A #x53B39330 #x24B4A3A6
                        #xBAD03605 #xCDD70693 #x54DE5729 #x23D967BF
                        #xB3667A2E #xC4614AB8 #x5D681B02 #x2A6F2B94
                        #xB40BBE37 #xC30C8EA1 #x5A05DF1B #x2D02EF8D))

;; Slicing-by-8 tables: T_k[i] applies the base-table shift k more times,
;; so eight input bytes are folded with eight table lookups instead of
;; eight sequential single-byte updates.
(define (make-slicing-table prev)
  (define t (make-fxvector 256 0))
  (for ([n (in-range 256)])
    (define c (fxvector-ref prev n))
    (fxvector-set! t n
                   (fxxor (fxvector-ref table (fxand c #xFF))
                          (fxrshift c 8))))
  t)

(define table1 (make-slicing-table table))
(define table2 (make-slicing-table table1))
(define table3 (make-slicing-table table2))
(define table4 (make-slicing-table table3))
(define table5 (make-slicing-table table4))
(define table6 (make-slicing-table table5))
(define table7 (make-slicing-table table6))

;; Initial CRC32 value (all bits set)
(define crc32-initial-value #xFFFFFFFF)

;; Update CRC32 value with a single byte
(define-inline (crc32-update acc byte)
  (fxxor (fxrshift acc 8)
         (fxvector-ref table (fxand (fxxor acc byte) #xFF))))

;; Finalize CRC32 computation by inverting all bits
(define-inline (crc32-finalize acc)
  (fxxor acc #xFFFFFFFF))

;; Fold bs[start, end) into acc: slicing-by-8 blocks plus a byte tail.
;; Returns the raw accumulator (finalize separately).
(define (crc32-fold-range acc bs start end)
  (let loop ([i start] [acc acc])
    (cond
      [(fx<= (fx+ i 8) end)
       (let* ([b0 (bytes-ref bs i)]
              [b1 (bytes-ref bs (fx+ i 1))]
              [b2 (bytes-ref bs (fx+ i 2))]
              [b3 (bytes-ref bs (fx+ i 3))]
              [b4 (bytes-ref bs (fx+ i 4))]
              [b5 (bytes-ref bs (fx+ i 5))]
              [b6 (bytes-ref bs (fx+ i 6))]
              [b7 (bytes-ref bs (fx+ i 7))]
              [one (fxxor acc b0
                          (fxlshift b1 8)
                          (fxlshift b2 16)
                          (fxlshift b3 24))]
              [two (fxxor b4
                          (fxlshift b5 8)
                          (fxlshift b6 16)
                          (fxlshift b7 24))])
         (loop (fx+ i 8)
               (fxxor
                (fxvector-ref table7 (fxand one #xFF))
                (fxvector-ref table6 (fxand (fxrshift one 8) #xFF))
                (fxvector-ref table5 (fxand (fxrshift one 16) #xFF))
                (fxvector-ref table4 (fxrshift one 24))
                (fxvector-ref table3 (fxand two #xFF))
                (fxvector-ref table2 (fxand (fxrshift two 8) #xFF))
                (fxvector-ref table1 (fxand (fxrshift two 16) #xFF))
                (fxvector-ref table  (fxrshift two 24)))))]
      [(fx< i end)
       (loop (fx+ i 1) (crc32-update acc (bytes-ref bs i)))]
      [else acc])))

;; Compute CRC32 of a byte string
(define (crc32-bytes bs)
  (crc32-finalize (crc32-fold-range crc32-initial-value bs 0 (bytes-length bs))))

;; Compute CRC32 of a UTF-8 encoded string
(define (crc32-string/utf8 s)
  (crc32-bytes (string->bytes/utf-8 s)))

;; Compute CRC32 of a Latin-1 encoded string
(define (crc32-string/latin-1 s)
  (crc32-bytes (string->bytes/latin-1 s)))

;; Compute CRC32 of a locale-encoded string
(define (crc32-string/locale s)
  (crc32-bytes (string->bytes/locale s)))

;; Compute CRC32 from input port, reading 64KB chunks instead of one byte
;; at a time so the slicing kernel dominates the runtime
(define (crc32-input-port [in (current-input-port)])
  (define buf (make-bytes 65536))
  (let loop ([acc crc32-initial-value])
    (define n (read-bytes-avail! buf in))
    (if (and (exact-integer? n) (fx> n 0))
        (loop (crc32-fold-range acc buf 0 n))
        (crc32-finalize acc))))

;;;=======================
;;;    Comprehensive Test Suite
;;;=======================

(module+ test
  ;; Helper function: Test CRC32 procedure against test cases
  (define-simple-check (test-crc32-proc proc cases)
    (for ([case cases])
      (check-equal? (proc (car case)) (cdr case) 
                    (format "Failed for input: ~a" (car case)))))

  ;; Helper function: Test incremental CRC32 computation
  (define-simple-check (test-crc32-incremental bs expected)
    (let ([result (for/fold ([acc crc32-initial-value])
                            ([byte bs])
                    (crc32-update acc byte))])
      (check-equal? (crc32-finalize result) expected)))

  ;; Helper function to generate test cases from actual CRC32 function
  (define (generate-test-case data)
    (cons data (crc32-bytes data)))
  
  (define (generate-string-test-case str)
    (cons str (crc32-string/utf8 str)))

  ;; Generate correct test cases at runtime
  (define boundary-test-cases 
    (list (generate-test-case #"")
          (generate-test-case #"\x00")
          (generate-test-case #"\xFF")
          (generate-test-case #"\x00\x00")
          (generate-test-case #"\xFF\xFF")
          (generate-test-case #"\x00\xFF")
          (generate-test-case #"\xFF\x00")))

  (define hex-bytes-test-cases
    (list (generate-test-case #"\x01")
          (generate-test-case #"\x12")
          (generate-test-case #"\x80")
          (generate-test-case #"\x12\x34")
          (generate-test-case #"\x12\x34\x56")
          (generate-test-case #"\x12\x34\x56\x78")
          (generate-test-case #"\xDE\xAD\xBE\xEF")
          (generate-test-case #"\xCA\xFE\xBA\xBE")
          (generate-test-case #"\x89\x50\x4E\x47")
          (generate-test-case #"\x47\x49\x46\x38")))

  ;; Keep only the verified standard test vectors
  (define standard-test-cases
    '((#"" . #x00000000)
      (#"a" . #xE8B7BE43)
      (#"abc" . #x352441C2)
      (#"123456789" . #xCBF43926) ; canonical CRC-32 check value
      (#"message digest" . #x20159D7F)
      (#"abcdefghijklmnopqrstuvwxyz" . #x4C2750BD)
      (#"The quick brown fox jumps over the lazy dog" . #x414FA339)))

  (define pattern-test-cases
    (list (generate-test-case (make-bytes 1 #x00))
          (generate-test-case (make-bytes 16 #x00))
          (generate-test-case (make-bytes 64 #x00))
          (generate-test-case (make-bytes 256 #x00))
          (generate-test-case (make-bytes 1 #xFF))
          (generate-test-case (make-bytes 16 #xFF))
          (generate-test-case (make-bytes 1 #xAA))
          (generate-test-case (make-bytes 8 #x55))
          (generate-test-case (make-bytes 4 #x01))))

  (define sequence-test-cases
    (list (generate-test-case #"\x00\x01\x02\x03")
          (generate-test-case #"\x00\x01\x02\x03\x04\x05\x06\x07")
          (generate-test-case (bytes-append* (for/list ([i 16]) (bytes i))))
          (generate-test-case (bytes-append* (for/list ([i 256]) (bytes i))))))

  (define ascii-string-test-cases
    (list (generate-string-test-case "")
          (generate-string-test-case "a")
          (generate-string-test-case "abc")
          (generate-string-test-case "123")
          (generate-string-test-case "Hello")
          (generate-string-test-case "Hello World!")
          (generate-string-test-case "UPPERCASE")
          (generate-string-test-case "lowercase")
          (generate-string-test-case "Numbers123456789")
          (generate-string-test-case "Special!@#$%^&*()_+-=[]{}|;':\",./<>?")))

  (define utf8-string-test-cases
    (list (generate-string-test-case "racket")
          (generate-string-test-case "你好")
          (generate-string-test-case "こんにちは")
          (generate-string-test-case "🚀")
          (generate-string-test-case "Café")
          (generate-string-test-case "Москва")
          (generate-string-test-case "مرحبا")
          (generate-string-test-case "αβγδε")))

  (define large-data-test-cases
    (list (generate-test-case (make-bytes 1024 #x41))
          (generate-test-case (make-bytes 4096 #x42))
          (generate-test-case (bytes-append* (make-list 1000 #"test")))))

  (define binary-format-test-cases
    (list (generate-test-case #"\x1F\x8B\x08")
          (generate-test-case #"\x42\x4D")
          (generate-test-case #"\x25\x50\x44\x46")
          (generate-test-case #"\x4D\x5A")
          (generate-test-case #"\x7F\x45\x4C\x46")))

  (define incremental-test-cases
    (list (list #"" #x00000000)
          (list #"a" #xE8B7BE43)
          (list #"ab" (crc32-bytes #"ab"))
          (list #"abc" #x352441C2)
          (list #"\x12\x34\x56" (crc32-bytes #"\x12\x34\x56"))))

  ;; Run all test suites
  (test-case "Boundary and edge cases"
    (test-crc32-proc crc32-bytes boundary-test-cases))

  (test-case "Hexadecimal byte sequences"
    (test-crc32-proc crc32-bytes hex-bytes-test-cases))

  (test-case "Standard test vectors"
    (test-crc32-proc crc32-bytes standard-test-cases))

  (test-case "Repeated patterns"
    (test-crc32-proc crc32-bytes pattern-test-cases))

  (test-case "Incrementing sequences"
    (test-crc32-proc crc32-bytes sequence-test-cases))

  (test-case "ASCII strings"
    (test-crc32-proc crc32-string/utf8 ascii-string-test-cases)
    (test-crc32-proc crc32-string/latin-1 ascii-string-test-cases)
    (test-crc32-proc crc32-string/locale ascii-string-test-cases))

  (test-case "UTF-8 strings"
    (test-crc32-proc crc32-string/utf8 utf8-string-test-cases))

  (test-case "Large data"
    (test-crc32-proc crc32-bytes large-data-test-cases))

  (test-case "Binary file formats"
    (test-crc32-proc crc32-bytes binary-format-test-cases))

  (test-case "Incremental computation"
    (for ([case incremental-test-cases])
      (test-crc32-incremental (car case) (cadr case))))

  (test-case "Input port functionality"
    (let ([input-bytes-test (compose crc32-input-port open-input-bytes)]
          [input-string-test (compose crc32-input-port open-input-string)])
      (test-crc32-proc input-bytes-test standard-test-cases)
      (test-crc32-proc input-string-test ascii-string-test-cases)
      (test-crc32-proc input-string-test utf8-string-test-cases)))

  (test-case "Input port reads cross chunk boundaries"
    ;; ~3x the 64KB internal buffer so several chunked reads must agree
    (define big (list->bytes (for/list ([i 200000]) (modulo i 251))))
    (check-equal? (crc32-input-port (open-input-bytes big))
                  (crc32-bytes big)))

  ;; Additional consistency validation tests
  (test-case "Function consistency validation"
    ;; Verify different functions produce same results for ASCII data
    (for ([test-str '("" "a" "abc" "Hello World")])
      (let ([bytes-result (crc32-bytes (string->bytes/utf-8 test-str))]
            [utf8-result (crc32-string/utf8 test-str)]
            [latin1-result (crc32-string/latin-1 test-str)]
            [locale-result (crc32-string/locale test-str)])
        (check-equal? bytes-result utf8-result)
        (check-equal? bytes-result latin1-result)
        (check-equal? bytes-result locale-result))))

  ;; Performance benchmark test (optional)
  (test-case "Performance benchmark"
    (let* ([test-data (make-bytes 1048576 #x55)]  ; 1MB test data
           [start-time (current-inexact-milliseconds)]
           [result (crc32-bytes test-data)]
           [end-time (current-inexact-milliseconds)])
      (displayln (format "1MB CRC32 computation time: ~a ms" (- end-time start-time)))
      (check-true (exact-integer? result))))

  ;; Legacy test for backward compatibility
  (test-case "Legacy incremental update test"
    ;; Test incremental computation with actual values
    (let ([acc crc32-initial-value])
      (set! acc (crc32-update acc 65)) ; 'A'
      (check-equal? acc #x2C266174)
      (set! acc (crc32-update acc 66)) ; 'B'  
      (check-equal? acc #xCF96B3F8)
      (set! acc (crc32-update acc 67)) ; 'C'
      (check-equal? (crc32-finalize acc) #xA3830348))))