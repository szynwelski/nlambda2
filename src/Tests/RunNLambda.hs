{-# LANGUAGE CPP #-}

import Tests.NLambda

#define DO_TEST(number) let (test, nlambda_test) = (test/**/number, nlambda_test/**/number/**/) in do {print "============================= Test number ==================================="; print nlambda_test; if show test == take (length $ show test) (show nlambda_test) then return () else (print test)}

main = do DO_TEST(1)
          DO_TEST(2)
          DO_TEST(3)
          DO_TEST(4)
          DO_TEST(5)
          DO_TEST(6)
          DO_TEST(7)
          DO_TEST(8)
          DO_TEST(9)
          DO_TEST(10)
          DO_TEST(11)
          DO_TEST(12)
          DO_TEST(13)
          DO_TEST(14)
          DO_TEST(15)
          DO_TEST(16)
          DO_TEST(17)
          DO_TEST(18)
          DO_TEST(19)
          DO_TEST(20)
          DO_TEST(21)
          DO_TEST(22)
          DO_TEST(23)
          DO_TEST(24)
          DO_TEST(25)
          DO_TEST(26)
          DO_TEST(27)
          DO_TEST(28)
          DO_TEST(29)
          DO_TEST(30)
          DO_TEST(31)
          DO_TEST(32)
          DO_TEST(33)
          DO_TEST(34)
          DO_TEST(35)
          DO_TEST(36)
          DO_TEST(37)
          DO_TEST(38)
          DO_TEST(39)
          DO_TEST(40)
          DO_TEST(41)
          DO_TEST(42)
          DO_TEST(43)
          DO_TEST(44)
          DO_TEST(45)
          DO_TEST(46)
          DO_TEST(47)
          DO_TEST(48)
          DO_TEST(49)
          DO_TEST(50)
          DO_TEST(51)
          DO_TEST(52)
          DO_TEST(53)
          DO_TEST(54)
          DO_TEST(55)
          DO_TEST(56)
          DO_TEST(57)
          DO_TEST(58)
