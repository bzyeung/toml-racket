#lang at-exp racket/base

(require gregor
         racket/function

         "../parsack.rkt"
         "../../main.rkt")

(module+ test
  (require rackunit
           racket/format)
  (check-equal? (parse-toml @~a{[a] })
                '#hasheq((a . #hasheq())))
  (check-equal? (parse-toml @~a{[a.b]})
                '#hasheq((a . #hasheq((b . #hasheq())))))
  (check-equal? (parse-toml @~a{today = 2014-06-26T12:34:56Z})
                `#hasheq((today . ,(moment 2014 6 26 12 34 56 #:tz 0))))
  ;; toml-tests: `duplicate-keys`
  (check-exn #rx"conflicting values for `x'"
             (λ () (parse-toml @~a{x=1
                                   x=2})))
  ;; toml-tests: `duplicate-tables`
  (check-exn #rx"redefinition of `a'"
             (λ () (parse-toml @~a{[a]
                                   [a]})))
  ;; toml-tests: table-sub-empty
  (check-equal? (parse-toml @~a{[a]
                                [a.b]})
                '#hasheq((a . #hasheq((b . #hasheq())))))
  ;; My own test for duplicate tables
  (check-exn #rx"redefinition of `a.b'"
             (λ () (parse-toml @~a{[a.b]
                                   [a.C]
                                   [a.b]
                                   })))
  (check-exn #rx"redefinition of `a'"
             (λ () (parse-toml @~a{[a]
                                   [b]
                                   [a]
                                   })))
  ;; README examples
  (check-equal? (parse-toml @~a{[a.b]
                                c = 1
                                [a]
                                d = 2})
                '#hasheq((a . #hasheq((b . #hasheq((c . 1)))
                                      (d . 2)))))
  (check-exn #rx"redefinition of `a'"
             (λ () (parse-toml @~a{[a]
                                   b = 1
                                   [a]
                                   c = 2})))
  (check-exn #rx"conflicting values for `a.b'"
             (λ () (parse-toml @~a{[a]
                                   b = 1
                                   [a.b]
                                   c = 2})))
  ;; See: https://github.com/toml-lang/toml/issues/846
  ;;      https://github.com/toml-lang/toml/pull/859
  (check-exn
   #rx"redefinition of `a.b.c' with dotted key"
   (λ () (parse-toml @~a{[a.b.c]
                         z = 9

                         [a]
                         b.c.t = "Dotted keys adding after explicit definition is invalid"})))
  ;; TOML v1.0.0 table examples
  (test-exn "Redefinition of table implied by dotted key prohibited"
            #rx"redefinition of `fruit.apple' with dotted key"
            (λ () (parse-toml @~a{[fruit]
                                  apple.color = "red"
                                  apple.taste.sweet = true

                                  [fruit.apple]})))
  (test-equal? "Subtable of table implied by dotted key allowed"
               (parse-toml @~a{[fruit]
                               apple.color = "red"
                               apple.taste.sweet = true

                               [fruit.apple.texture]
                               smooth = true})
               '#hasheq((fruit . #hasheq((apple . #hasheq((color . "red")
                                                          (taste . #hasheq((sweet . #t)))
                                                          (texture . #hasheq((smooth . #t)))))))))
  (test-exn "Cannot add to inline table"
            #rx"redefinition of `product.type`" ; TODO terminal error character inconsistency?
            (λ () (parse-toml @~a{[product]
                                  type = { name = "Nail" }
                                  type.edible = false})))
  (test-exn "Inline table cannot add to already-defined table"
            #rx"conflicting values for `product.type'" ; TODO consider improving error?
            (λ () (parse-toml @~a{[product]
                                  type.name = "Nail"
                                  type = { edible = false }})))
  (check-exn exn:fail:parsack? (λ () (parse-toml "[]")))
  (check-exn exn:fail:parsack? (λ () (parse-toml "[a.]")))
  (check-exn exn:fail:parsack? (λ () (parse-toml "[a..b]")))
  (check-exn exn:fail:parsack? (λ () (parse-toml "[.b]")))
  (check-exn exn:fail:parsack? (λ () (parse-toml "[.]")))
  (check-exn exn:fail:parsack? (λ () (parse-toml " = 0")))
  (check-equal?
   (parse-toml @~a{[[aot.sub]] #comment
                   aot0 = 10
                   aot1 = 11

                   [[aot.sub]] #comment
                   aot0 = 20
                   aot1 = 21

                   [[aot.sub]] #comment
                   aot0 = 30
                   aot1 = 31
                   })
   '#hasheq((aot
             .
             #hasheq((sub
                      .
                      (#hasheq((aot0 . 10) (aot1 . 11))
                       #hasheq((aot0 . 20) (aot1 . 21))
                       #hasheq((aot0 . 30) (aot1 . 31))))))))

  (test-equal?
   "Parse a long toml document"
   (parse-toml @~a{# Comment blah blah
                   # Comment blah blah

                   foo = "bar" #comment
                   ten = 10
                   true = true
                   false = false
                   array0 = [1,2,3] #comment
                   array1 = [ 1, 2, 3, ]
                   array2 = [ #comment
                              1, #comment
                              2,
                              3,
                              ] #comment
                   nested-array = [[1, 2, 3], [4, 5, 6]] #comment

                   [key0.key1] #comment
                   x = 1
                   y = 1
                   [key0.key2]
                   x = 1
                   y = 1

                   [[aot.sub]] #comment
                   aot0 = 10
                   aot1 = 11

                   [[aot.sub]] #comment
                   aot0 = 20
                   aot1 = 21

                   [[aot.sub]] #comment
                   aot0 = 30
                   aot1 = 31
                   })
   '#hasheq((foo . "bar")
            (false . #f)
            (true . #t)
            (aot
             .
             #hasheq((sub
                      .
                      (#hasheq((aot0 . 10) (aot1 . 11))
                       #hasheq((aot0 . 20) (aot1 . 21))
                       #hasheq((aot0 . 30) (aot1 . 31))))))
            (ten . 10)
            (array0 . (1 2 3))
            (array1 . (1 2 3))
            (array2 . (1 2 3))
            (nested-array . ((1 2 3) (4 5 6)))
            (key0
             .
             #hasheq((key1 . #hasheq((x . 1) (y . 1)))
                     (key2 . #hasheq((x . 1) (y . 1)))))))
  (check-equal?
   (parse-toml @~a{[[fruit]]
                   name = "apple"

                   [fruit.physical]
                   color = "red"
                   shape = "round"

                   [[fruit]]
                   name = "banana"
                   })
   '#hasheq((fruit
             .
             (#hasheq((name . "apple")
                      (physical
                       .
                       #hasheq((color . "red") (shape . "round"))))
              #hasheq((name . "banana"))))))
  (test-equal?
   "Parse tables with CRLF"
   (parse-toml @~a{[[fruit]]@"\r"
                   name = "apple"@"\r"
                   @"\r"
                   [fruit.physical]@"\r"
                   color = "red"@"\r"
                   shape = "round"@"\r"
                   @"\r"
                   [[fruit]]@"\r"
                   name = "banana"})
   '#hasheq((fruit
             .
             (#hasheq((name . "apple")
                      (physical
                       .
                       #hasheq((color . "red") (shape . "round"))))
              #hasheq((name . "banana"))))))
  ;; From TOML README
  (check-equal?
   (parse-toml @~a{[[fruit]]
                   name = "apple"

                   [fruit.physical]
                   color = "red"
                   shape = "round"

                   [[fruit.variety]]
                   name = "red delicious"

                   [[fruit.variety]]
                   name = "granny smith"

                   [[fruit]]
                   name = "banana"

                   [[fruit.variety]]
                   name = "plantain"
                   })
   '#hasheq((fruit
             .
             (#hasheq((name . "apple")
                      (physical
                       .
                       #hasheq((color . "red") (shape . "round")))
                      (variety
                       .
                       (#hasheq((name . "red delicious"))
                        #hasheq((name . "granny smith")))))
              #hasheq((name . "banana")
                      (variety
                       .
                       (#hasheq((name . "plantain")))))))))
  ;; https://github.com/toml-lang/toml/issues/214
  (check-equal?
   (parse-toml @~a{[[foo.bar]]})
   (parse-toml @~a{[foo]
                   [[foo.bar]]}))
  ;; example from TOML README
  (check-exn
   #rx"conflicting values for `fruit.variety'"
   (λ () (parse-toml @~a{# INVALID TOML DOC
                         [[fruit]]
                         name = "apple"

                         [[fruit.variety]]
                         name = "red delicious"

                         # This table conflicts with the previous table
                         [fruit.variety]
                         name = "granny smith"})))
  ;; https://github.com/toml-lang/toml/pull/199#issuecomment-47300021
  ;; The tables and arrays of tables may come in ANY order. A plain table
  ;; may come "in the middle" of a nested table definition.
  (check-equal?
   (parse-toml @~a{[table]
                   key = 5

                   [[table.array]]
                   a = 1
                   b = 2

                   [another-table]
                   key = 10

                   [[table.array]]
                   a = 2
                   b = 4})
   #hasheq((|another-table| . #hasheq((key . 10)))
           (table . #hasheq((key . 5)
                            (array . (#hasheq((a . 1) (b . 2))
                                      #hasheq((a . 2) (b . 4))))))))

  (check-exn #rx""
             (λ () (parse-toml @~a{
                                   [a#b]
                                   x=1
                                   }))
             "Invalid character in table name")

  (check-equal?
   (parse-toml @~a{a.b.c = true})
   #hasheq((a . #hasheq((b . #hasheq((c . #t)))))))

  (check-exn #rx""
             (thunk
              (parse-toml @~a{
                              x = [1 2 3]
                              })))

  (test-equal?
   "Empty document is valid TOML"
   (parse-toml "")
   #hasheq())

  (test-equal? "Whitespace is valid TOML" (parse-toml " ") #hasheq())
  (test-equal? "Lone comment is valid TOML"
               (parse-toml " # comment")
               #hasheq())

  (test-exn "Bare CR is not valid TOML"
            exn:fail:parsack?
            (thunk (parse-toml "\r")))

  (test-equal? "Newlines can be CRLF"
               (parse-toml "os=\"Windows\"\r\nnewline=\"CRLF\"")
               '#hasheq((os . "Windows") (newline . "CRLF")))

  (test-exn "Should not parse multiline key"
            #rx""
            (thunk (parse-toml @~a{
                                   """test""" = 1
                                   })))

  (test-exn "Should not parse unicode key"
            #rx""
            (thunk (parse-toml "µ = 1"))))
