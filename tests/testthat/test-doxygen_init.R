test_that("doxygen_init creates the configuration file with INPUT folder and clean.doxygen cleans up",{
          doxy_file <- "inst/doxygen/Doxyfile"
          # clean up before
          clean.doxygen(base_path=".")
          
          # make doxygen structure and test
          suppressWarnings(doxygen_ok <- doxygen_init(doxy_file))
          if(doxygen_ok){
              config <- readLines(doxy_file)
              expect_equal(length(grep("INPUT .* src/",config)),1)
              expect_true(file.exists(doxy_file))
          }

          # clean up after and test clean 
          clean.doxygen(base_path=".")
          expect_true(! file.exists(doxy_file))
})
test_that("check_doxygen returns an error if needed",{
          expect_error(check_doxygen(".","aezrezarzerazer"))
})
