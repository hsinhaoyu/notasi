;;; Unit tests for (notasi json-writer): the JSON writer.
;;;
;;; Written from doc/design/05-typst-backend.md ("JSON writing"), not
;;; from the implementation.
;;;
;;; Choices where the spec leaves room (also noted at the tests):
;;; - Compact separators are "," and ":" with no space; pretty arrays
;;;   on one line use ", " between elements (as in the spec's
;;;   ["neng1", "nong1"]).
;;; - An array holding an empty object or empty array is not "all
;;;   scalars", so it has one element per line.
;;; - Compact write-json adds no trailing newline: the spec says compact
;;;   output has "no spaces or newlines at all" and only pretty output
;;;   ends with one.
;;; - The symbol key a and the string key "a" are the same key (both
;;;   are written as "a"), so giving both is a duplicate-key error.
;;; - The offending value for a non-alist pair is the pair itself; for
;;;   a plain list such as (1 2 3) the list or its first element is
;;;   accepted.

(use-modules (srfi srfi-64)
             (ice-9 exceptions)
             (notasi json-writer))

;;; ------------------------------------------------------------------
;;; Helpers

(define (lines . strs)
  "Join STRS with newlines (no trailing newline)."
  (string-join strs "\n"))

(define (compact v) (json-string v #:pretty? #f))
(define (pretty v) (json-string v))

(define (irritants-of thunk)
  "The irritants of the &error raised by THUNK, or the symbol no-error
if THUNK returns, or not-an-error if it raises something else."
  (guard (e ((error? e)
             (if (exception-with-irritants? e) (exception-irritants e) '()))
            (#t 'not-an-error))
    (thunk)
    'no-error))

(define (raises-with? value thunk)
  "True if THUNK raises an &error whose irritants include VALUE."
  (let ((irr (irritants-of thunk)))
    (and (list? irr) (member value irr) #t)))

(define (bad-value? value)
  "True if writing VALUE (alone, compact) raises an &error naming it."
  (raises-with? value (lambda () (compact value))))

(test-begin "json")

;;; ------------------------------------------------------------------
;;; Mapping table (compact output, so layout does not get in the way)

(test-group "objects"
  (test-equal "alist with symbol keys" "{\"a\":1,\"b\":2}"
    (compact '((a . 1) (b . 2))))
  (test-equal "keys keep the given order, not sorted" "{\"b\":1,\"a\":2,\"c\":3}"
    (compact '((b . 1) (a . 2) (c . 3))))
  (test-equal "string keys" "{\"x y\":1,\"z\":2}"
    (compact '(("x y" . 1) ("z" . 2))))
  (test-equal "mixed symbol and string keys" "{\"a\":1,\"b\":2}"
    (compact '((a . 1) ("b" . 2))))
  (test-equal "empty list is an empty object" "{}" (compact '()))
  (test-equal "key whose value is '() is an empty object" "{\"a\":{}}"
    (compact '((a))))
  (test-equal "same key in two different objects is fine"
    "[{\"a\":1},{\"a\":2}]"
    (compact '#(((a . 1)) ((a . 2)))))
  (test-equal "a key named null" "{\"null\":null}"
    (compact '((null . null)))))

(test-group "arrays"
  (test-equal "vector is an array" "[1,2,3]" (compact #(1 2 3)))
  (test-equal "empty vector is an empty array" "[]" (compact #()))
  (test-equal "mixed scalars" "[\"a\",1,true,false,null]"
    (compact #("a" 1 #t #f null)))
  (test-equal "nested arrays" "[[1],[],[[2]]]"
    (compact '#(#(1) #() #(#(2))))))

(test-group "strings"
  (test-equal "plain string" "\"neng1\"" (compact "neng1"))
  (test-equal "empty string" "\"\"" (compact "")))

(test-group "numbers"
  (test-equal "zero" "0" (compact 0))
  (test-equal "positive integer" "42" (compact 42))
  (test-equal "negative integer" "-7" (compact -7))
  (test-equal "big integer" "1000000000000000000000000000000"
    (compact (expt 10 30)))
  (test-equal "inexact real" "1.5" (compact 1.5))
  (test-equal "negative inexact real" "-0.25" (compact -0.25))
  (test-equal "whole inexact real uses number->string" (number->string 2.0)
    (compact 2.0))
  (test-equal "large inexact real uses number->string" (number->string 1e21)
    (compact 1e21)))

(test-group "booleans and null"
  (test-equal "#t" "true" (compact #t))
  (test-equal "#f" "false" (compact #f))
  (test-equal "the symbol null" "null" (compact 'null))
  (test-equal "'() is an object, not null or false" "{}" (compact '())))

(test-group "nesting"
  (test-equal "object in object in array"
    "[{\"a\":{\"b\":[1,{\"c\":null}]}}]"
    (compact '#(((a . ((b . #(1 ((c . null))))))))))
  (test-equal "array of objects as a member"
    "{\"voices\":[{\"name\":\"polos\"},{\"name\":\"sangsih\"}]}"
    (compact '((voices . #(((name . "polos")) ((name . "sangsih"))))))))

;;; ------------------------------------------------------------------
;;; Compact output

(test-group "compact output"
  (test-equal "the spec's example" "{\"a\":1,\"b\":[1,2]}"
    (compact '((a . 1) (b . #(1 2)))))
  (test-assert "no spaces or newlines anywhere"
    (let ((s (compact '((a . 1) (b . #(1 "x" ((c . #()) (d . ()))))))))
      (not (or (string-index s #\space) (string-index s #\newline)))))
  (test-equal "spaces inside strings are kept" "{\"a b\":\"c d\"}"
    (compact '(("a b" . "c d")))))

;;; ------------------------------------------------------------------
;;; Pretty output

(test-group "pretty output"
  (test-equal "default is pretty" (pretty '((a . 1)))
    (json-string '((a . 1)) #:pretty? #t))
  (test-equal "object members one per line, 2-space indent"
    (lines "{"
           "  \"a\": 1,"
           "  \"b\": \"x\""
           "}")
    (pretty '((a . 1) (b . "x"))))
  (test-equal "scalar-only array on one line, comma and space"
    (lines "{"
           "  \"lanes\": [\"neng1\", \"nong1\"],"
           "  \"n\": [1, 2.5, true, false, null]"
           "}")
    (pretty '((lanes . #("neng1" "nong1")) (n . #(1 2.5 #t #f null)))))
  (test-equal "top-level scalar-only array" "[\"a\", \"b\"]"
    (pretty #("a" "b")))
  (test-equal "array with an object has one element per line"
    (lines "["
           "  {"
           "    \"a\": 1"
           "  },"
           "  2"
           "]")
    (pretty '#(((a . 1)) 2)))
  (test-equal "array with an array has one element per line"
    (lines "["
           "  [1, 2],"
           "  \"x\""
           "]")
    (pretty '#(#(1 2) "x")))
  (test-equal "nested indentation"
    (lines "{"
           "  \"a\": {"
           "    \"b\": {"
           "      \"c\": [1]"
           "    }"
           "  }"
           "}")
    (pretty '((a . ((b . ((c . #(1)))))))))
  (test-equal "empty object" "{}" (pretty '()))
  (test-equal "empty array" "[]" (pretty #()))
  (test-equal "empties inside a pretty object"
    (lines "{"
           "  \"o\": {},"
           "  \"a\": []"
           "}")
    (pretty '((o . ()) (a . #()))))
  ;; Choice: {} and [] are not scalars, so they force one per line.
  (test-equal "array holding empties has one element per line"
    (lines "["
           "  {},"
           "  []"
           "]")
    (pretty '#(() #())))
  (test-equal "top-level number" "42" (pretty 42))
  (test-equal "top-level string" "\"x\"" (pretty "x"))
  (test-equal "top-level null" "null" (pretty 'null)))

;;; ------------------------------------------------------------------
;;; write-json and newlines

(test-group "write-json"
  (test-assert "json-string pretty has no trailing newline"
    (not (string-suffix? "\n" (pretty '((a . 1))))))
  (test-assert "json-string compact has no trailing newline"
    (not (string-suffix? "\n" (compact '((a . 1))))))
  (test-equal "pretty write-json is json-string plus one newline"
    (string-append (pretty '((a . 1) (b . #(1 2)))) "\n")
    (call-with-output-string
      (lambda (port) (write-json '((a . 1) (b . #(1 2))) port))))
  (test-equal "pretty write-json of a scalar ends with one newline" "1\n"
    (call-with-output-string (lambda (port) (write-json 1 port))))
  ;; Choice: "no spaces or newlines at all" covers write-json too.
  (test-equal "compact write-json to a port" "{\"a\":1,\"b\":[1,2]}"
    (call-with-output-string
      (lambda (port) (write-json '((a . 1) (b . #(1 2))) port #:pretty? #f))))
  (test-equal "no port writes to current-output-port"
    (string-append (pretty '((a . #("x")))) "\n")
    (with-output-to-string (lambda () (write-json '((a . #("x")))))))
  (test-equal "no port, compact" "[1,2]"
    (with-output-to-string (lambda () (write-json #(1 2) #:pretty? #f)))))

;;; ------------------------------------------------------------------
;;; String escaping

(define (ch n) (string (integer->char n)))

(test-group "escaping"
  (test-equal "double quote" "\"a\\\"b\"" (compact "a\"b"))
  (test-equal "backslash" "\"a\\\\b\"" (compact "a\\b"))
  (test-equal "newline" "\"a\\nb\"" (compact "a\nb"))
  (test-equal "carriage return" "\"a\\rb\"" (compact "a\rb"))
  (test-equal "tab" "\"a\\tb\"" (compact "a\tb"))
  (test-equal "backspace U+0008" "\"\\b\"" (compact (ch 8)))
  (test-equal "form feed U+000C" "\"\\f\"" (compact (ch 12)))
  (test-equal "U+0000 as \\u0000" "\"\\u0000\"" (compact (ch 0)))
  (test-equal "U+0001 as \\u0001" "\"\\u0001\"" (compact (ch 1)))
  (test-equal "U+001B as \\u001b, lowercase hex" "\"\\u001b\"" (compact (ch #x1b)))
  (test-equal "U+001F as \\u001f, lowercase hex" "\"\\u001f\"" (compact (ch #x1f)))
  (test-equal "U+007F is not escaped" (string-append "\"" (ch #x7f) "\"")
    (compact (ch #x7f)))
  (test-equal "space is not escaped" "\" \"" (compact " "))
  (test-equal "slash is not escaped" "\"a/b\"" (compact "a/b"))
  (test-equal "non-ASCII written as-is" "\"·é🎵ꦧ\"" (compact "·é🎵ꦧ"))
  (test-equal "keys are escaped too" "{\"a\\\"b\\n\":1}"
    (compact '(("a\"b\n" . 1))))
  (test-equal "escaping in pretty output"
    (lines "{"
           "  \"t\\t\": [\"a\\\\\", \"\\u0002\"]"
           "}")
    (pretty `(("t\t" . #("a\\" ,(ch 2)))))))

;;; ------------------------------------------------------------------
;;; Errors: an &error whose irritants include the offending value

(define (proc x) x)

(test-group "errors"
  (test-assert "another symbol" (bad-value? 'foo))
  (test-assert "the symbol true is not #t" (bad-value? 'true))
  (test-assert "a rational 1/2" (bad-value? 1/2))
  (test-assert "+inf.0" (bad-value? +inf.0))
  (test-assert "-inf.0" (bad-value? -inf.0))
  (test-assert "+nan.0" (bad-value? +nan.0))
  (test-assert "a complex number" (bad-value? 1+2i))
  (test-assert "a procedure" (bad-value? proc))
  (test-assert "a character" (bad-value? #\a))
  (test-assert "a pair that is not an alist, as a value"
    (raises-with? '(1 . 2) (lambda () (compact '((a . (1 . 2)))))))
  (test-assert "a pair that is not an alist, top level"
    (bad-value? '(1 . 2)))
  ;; Choice: the offending value may be the list or its first element.
  (test-assert "a plain list (1 2 3)"
    (let ((irr (irritants-of (lambda () (compact '((a . (1 2 3))))))))
      (and (list? irr)
           (or (member '(1 2 3) irr) (member 1 irr))
           #t)))
  (test-assert "a number key" (raises-with? 1 (lambda () (compact '((1 . "x"))))))
  (test-assert "a boolean key" (raises-with? #t (lambda () (compact '((#t . "x"))))))
  (test-assert "a duplicate symbol key"
    (raises-with? 'a (lambda () (compact '((a . 1) (b . 2) (a . 3))))))
  (test-assert "a duplicate string key"
    (raises-with? "a" (lambda () (compact '(("a" . 1) ("a" . 2))))))
  ;; Choice: a and "a" are both written as "a", so they collide.
  (test-assert "symbol a and string \"a\" are the same key"
    (let ((irr (irritants-of (lambda () (compact '((a . 1) ("a" . 2)))))))
      (and (list? irr) (or (member 'a irr) (member "a" irr)) #t)))
  (test-assert "a duplicate key in a nested object"
    (raises-with? 'k (lambda () (compact `#(1 ((x . ((k . 1) (k . 2)))))))))
  (test-assert "bad value deep inside"
    (raises-with? 'oops
      (lambda () (compact `((a . #(1 ((b . #(#(2 oops)))))))))))
  (test-assert "bad value deep inside, pretty"
    (raises-with? 1/3 (lambda () (pretty `((a . ((b . #(,1/3)))))))))
  (test-assert "write-json raises too"
    (raises-with? 'foo
      (lambda () (call-with-output-string
                   (lambda (port) (write-json '((a . foo)) port)))))))

;;; ------------------------------------------------------------------
;;; A small figure in the shape of the version 1 contract

(define figure
  '((version . 1)
    (title . "Reyong kotekan")
    (steps_per_pulse . 4)
    (sizes . ((label_width . "10.5em") (lane_width . "3.6em")))
    (systems
     . #(((start . 0)
          (steps . 12)
          (groups
           . #(((label . "Reyong")
                (subtitle . "polos + sangsih")
                (lanes . #("neng1" "nong1"))
                (voices
                 . #(((name . "polos")
                      (events
                       . #(((start . 0) (dur . 2) (lane . 1) (text . "a")
                            (fill . "#66a61e") (text_color . "#ffffff")
                            (continued . #f))
                           ((start . 2) (dur . 1) (lane . 0) (text . "·")
                            (fill . null) (text_color . "#000000")
                            (continued . #t)))))))))))))
    (caption . "Reyong kotekan with gong.")))

(test-group "figure"
  (test-equal "full pretty output"
    (lines "{"
           "  \"version\": 1,"
           "  \"title\": \"Reyong kotekan\","
           "  \"steps_per_pulse\": 4,"
           "  \"sizes\": {"
           "    \"label_width\": \"10.5em\","
           "    \"lane_width\": \"3.6em\""
           "  },"
           "  \"systems\": ["
           "    {"
           "      \"start\": 0,"
           "      \"steps\": 12,"
           "      \"groups\": ["
           "        {"
           "          \"label\": \"Reyong\","
           "          \"subtitle\": \"polos + sangsih\","
           "          \"lanes\": [\"neng1\", \"nong1\"],"
           "          \"voices\": ["
           "            {"
           "              \"name\": \"polos\","
           "              \"events\": ["
           "                {"
           "                  \"start\": 0,"
           "                  \"dur\": 2,"
           "                  \"lane\": 1,"
           "                  \"text\": \"a\","
           "                  \"fill\": \"#66a61e\","
           "                  \"text_color\": \"#ffffff\","
           "                  \"continued\": false"
           "                },"
           "                {"
           "                  \"start\": 2,"
           "                  \"dur\": 1,"
           "                  \"lane\": 0,"
           "                  \"text\": \"·\","
           "                  \"fill\": null,"
           "                  \"text_color\": \"#000000\","
           "                  \"continued\": true"
           "                }"
           "              ]"
           "            }"
           "          ]"
           "        }"
           "      ]"
           "    }"
           "  ],"
           "  \"caption\": \"Reyong kotekan with gong.\""
           "}")
    (pretty figure))
  (test-assert "compact figure has the lanes array"
    (string-contains (compact figure) "\"lanes\":[\"neng1\",\"nong1\"]"))
  (test-assert "compact figure starts with version"
    (string-prefix? "{\"version\":1,\"title\":\"Reyong kotekan\"," (compact figure))))

(define runner (test-runner-current))
(test-end "json")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
