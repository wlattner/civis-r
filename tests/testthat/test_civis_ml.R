library(mockery)

test_that("jsonlite works", {
  # The tests below fail when run via R CMD check due with a
  # "invalid encoding argument" error. jsonlite::toJSON is the last thing in
  # the traceback. Adding this test here seems to make the issue go away.
  # TODO: find out why.
  s <- jsonlite::toJSON(list(sample_weight = "survey_weights"), auto_unbox = TRUE)
  expect_equal(unclass(s), "{\"sample_weight\":\"survey_weights\"}")
})

################################################################################
# Build
context("civis_ml")

test_that("calls scripts_post_custom", {
  fake_get_database_id <- mock(456, cycle = TRUE)
  fake_scripts_post_custom <- mock(list(id = 999))
  fake_scripts_post_custom_runs <- mock(list(id = 888))
  fake_scripts_get_custom_runs <- mock(list(state = "running"), list(state = "succeeded"))
  fake_civis_ml_fetch_existing <- mock(NULL)
  fake_getOption <- mock(1111, cycle = TRUE)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::scripts_post_custom` = fake_scripts_post_custom,
    `civis::scripts_post_custom_runs` = fake_scripts_post_custom_runs,
    `civis::scripts_get_custom_runs` = fake_scripts_get_custom_runs,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,
    `base::getOption` = fake_getOption,

    tbl <- civis_table(table_name = "schema.table",
                       database_name = "a_database",
                       sql_where = "1 = 2",
                       sql_limit = 10),

    civis_ml(x = tbl,
             model_type = "sparse_logistic",
             dependent_variable = "target",
             excluded_columns = c("col_1", "col_2", "col_3"),
             primary_key = "row_number",
             parameters = list(n_estimators = 10),
             cross_validation_parameters = list(n_estimators = c(10, 20, 30)),
             model_name = "awesome civisml",
             calibration = "sigmoid",
             oos_scores_table = "score.table",
             oos_scores_db = "another_database",
             oos_scores_if_exists = "drop",
             fit_params = list(sample_weight = "survey_weights"),
             cpu_requested = 1111,
             memory_requested = 9096,
             disk_requested = 9,
             notifications = list(successEmailSubject = "A success",
                                  successEmailAddresses = c("user@example.com")),
             polling_interval = 5,
             verbose = FALSE)
  )

  script_args <- mock_args(fake_scripts_post_custom)[[1]]
  expect_equal(script_args$from_template_id, 1111)
  expect_equal(script_args$name, "awesome civisml Train")
  expect_equal(script_args$notifications, list(successEmailSubject = "A success",
                                               successEmailAddresses = c("user@example.com")))

  # These are template args/params:
  ml_args <- script_args$arguments
  expect_is(ml_args, "AsIs")  # We don't want jsonlite doing anything unexpected.
  expect_equal(ml_args$MODEL, "sparse_logistic")
  expect_equal(ml_args$TARGET_COLUMN, "target")
  expect_equal(ml_args$PRIMARY_KEY, "row_number")
  expect_equal(unclass(ml_args$PARAMS), '{"n_estimators":10}')
  expect_equal(unclass(ml_args$CVPARAMS), '{"n_estimators":[10,20,30]}')
  expect_equal(ml_args$CALIBRATION, "sigmoid")
  expect_equal(ml_args$IF_EXISTS, "drop")
  expect_equal(ml_args$TABLE_NAME, "schema.table")
  expect_equal(ml_args$CIVIS_FILE_ID, NULL)
  expect_equal(ml_args$OOSTABLE, "score.table")
  expect_equal(ml_args$OOSDB, list(database = 456))
  expect_equal(ml_args$WHERESQL, "1 = 2")
  expect_equal(ml_args$LIMITSQL, 10)
  expect_equal(ml_args$EXCLUDE_COLS, "col_1 col_2 col_3")
  expect_equal(unclass(ml_args$FIT_PARAMS), '{"sample_weight":"survey_weights"}')
  expect_equal(ml_args$DB, list(database = 456))
  expect_equal(ml_args$REQUIRED_CPU, 1111)
  expect_equal(ml_args$REQUIRED_MEMORY, 9096)
  expect_equal(ml_args$REQUIRED_DISK_SPACE, 9)

  # Make sure we started the job.
  expect_args(fake_scripts_post_custom_runs, 1, 999)

  # And checked it's status
  expect_args(fake_scripts_get_custom_runs, 1, 999, 888)
  expect_called(fake_scripts_get_custom_runs, 2)
})

test_that("calls civis_ml.data.frame for local df", {
  fake_write_csv <- mock(NULL)
  fake_temp_file <- mock("fake_temp_path")
  fake_write_civis_file <- mock(1234)
  fake_get_database_id <- mock(456)
  fake_create_and_run_model <- mock(NULL)

  with_mock(
    `utils::write.csv` = fake_write_csv,
    `base::tempfile` = fake_temp_file,
    `civis::write_civis_file` = fake_write_civis_file,
    `civis::get_database_id` = fake_get_database_id,
    `civis::create_and_run_model` = fake_create_and_run_model,

    civis_ml(iris,
             model_type = "sparse_logistic",
             dependent_variable = "the_target_column",
             primary_key = "the_pk_column"),

    expect_args(fake_write_civis_file, 1,
                path = "fake_temp_path",
                name = "modelpipeline_data.csv"),

    expect_args(fake_create_and_run_model, 1,
                file_id = 1234,
                dependent_variable = "the_target_column",
                excluded_columns = NULL,
                primary_key = "the_pk_column",
                model_type = "sparse_logistic",
                parameters = NULL,
                cross_validation_parameters = NULL,
                fit_params = NULL,
                calibration = NULL,
                oos_scores_table = NULL,
                oos_scores_db_id = NULL,
                oos_scores_if_exists = 'fail',
                model_name = NULL,
                cpu_requested = NULL,
                memory_requested = NULL,
                disk_requested = NULL,
                notifications = NULL,
                verbose = FALSE)
  )
})

test_that("calls civis_ml.civis_table for table_name", {
  fake_get_database_id <- mock(456)
  fake_create_and_run_model <- mock(NULL)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::create_and_run_model` = fake_create_and_run_model,

    x <- civis_table(table_name = "a_schema.table",
                     database_name = "a_database",
                     sql_where = "a = b",
                     sql_limit = 6),

    civis_ml(x = x,
             model_type = "sparse_logistic",
             dependent_variable = "the_target_column",
             primary_key = "the_pk_column")
  )

  expect_args(fake_get_database_id, 1, "a_database")

  expect_args(fake_create_and_run_model, 1,
              table_name = "a_schema.table",
              database_id = 456,
              sql_where = "a = b",
              sql_limit = 6,
              dependent_variable = "the_target_column",
              excluded_columns = NULL,
              primary_key = "the_pk_column",
              model_type = "sparse_logistic",
              parameters = NULL,
              cross_validation_parameters = NULL,
              fit_params = NULL,
              calibration = NULL,
              oos_scores_table = NULL,
              oos_scores_db_id = NULL,
              oos_scores_if_exists = 'fail',
              model_name = NULL,
              cpu_requested = NULL,
              memory_requested = NULL,
              disk_requested = NULL,
              notifications = NULL,
              verbose = FALSE)
})

test_that("calls civis_ml.civis_file for file_id", {
  fake_get_database_id <- mock(456)
  fake_create_and_run_model <- mock(NULL)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::create_and_run_model` = fake_create_and_run_model,

    civis_ml(x = civis_file(file_id = 123),
             model_type = "sparse_logistic",
             dependent_variable = "the_target_column",
             primary_key = "the_pk_column")
  )

  expect_args(fake_create_and_run_model, 1,
              file_id = civis_file(123),
              dependent_variable = "the_target_column",
              excluded_columns = NULL,
              primary_key = "the_pk_column",
              model_type = "sparse_logistic",
              parameters = NULL,
              cross_validation_parameters = NULL,
              fit_params = NULL,
              calibration = NULL,
              oos_scores_table = NULL,
              oos_scores_db_id = NULL,
              oos_scores_if_exists = 'fail',
              model_name = NULL,
              cpu_requested = NULL,
              memory_requested = NULL,
              disk_requested = NULL,
              notifications = NULL,
              verbose = FALSE)
})

test_that("calls civis_ml.character for local csv", {
  fake_get_database_id <- mock(456)
  fake_write_civis_file <- mock(123)
  fake_create_and_run_model <- mock(NULL)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::write_civis_file` = fake_write_civis_file,
    `civis::create_and_run_model` = fake_create_and_run_model,

    civis_ml(x =  "fake_temp_path",
             model_type = "sparse_logistic",
             dependent_variable = "the_target_column",
             primary_key = "the_pk_column")
  )

  expect_args(fake_write_civis_file, 1,
              path = "fake_temp_path",
              name = "modelpipeline_data.csv")

  expect_args(fake_create_and_run_model, 1,
              file_id = 123,
              dependent_variable = "the_target_column",
              excluded_columns = NULL,
              primary_key = "the_pk_column",
              model_type = "sparse_logistic",
              parameters = NULL,
              cross_validation_parameters = NULL,
              fit_params = NULL,
              calibration = NULL,
              oos_scores_table = NULL,
              oos_scores_db_id = NULL,
              oos_scores_if_exists = 'fail',
              model_name = NULL,
              cpu_requested = NULL,
              memory_requested = NULL,
              disk_requested = NULL,
              notifications = NULL,
              verbose = FALSE)
})

test_that("raises error on invalid calibration", {
  fake_get_database_id <- mock(456)
  fake_write_civis_file <- mock(123)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::write_civis_file` = fake_write_civis_file,

    expect_error(civis_ml(x = "fake_temp_path",
                          model_type = "sparse_logistic",
                          dependent_variable = "target",
                          primary_key = "pk",
                          calibration = "fake"),
                 "calibration must be 'sigmoid', 'isotonic', or NULL\\.")
  )
})

################################################################################
# Predict
context("predict.civis_ml")

fake_model <- structure(
  list(
    job = list(
      id = 123,
      name = "model_task",
      arguments = list(
        PRIMARY_KEY = "training_primary_key"
      )
    ),
    run = list(id = 456)
  ),
  class = "civis_ml"
)

test_that("calls scripts_post_custom", {
  fake_get_database_id <- mock(456, cycle = TRUE)
  fake_scripts_post_custom <- mock(list(id = 999))
  fake_scripts_post_custom_runs <- mock(list(id = 888))
  fake_scripts_get_custom_runs <- mock(list(state = "running"), list(state = "succeeded"))
  fake_fetch_predict_results <- mock(NULL)
  fake_getOption <- mock(1111, cycle = TRUE)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::scripts_post_custom` = fake_scripts_post_custom,
    `civis::scripts_post_custom_runs` = fake_scripts_post_custom_runs,
    `civis::scripts_get_custom_runs` = fake_scripts_get_custom_runs,
    `civis::fetch_predict_results` = fake_fetch_predict_results,
    `base::getOption` = fake_getOption,

    tbl <- civis_table(table_name = "schema.table",
                       database_name = "a_database",
                       sql_where = "6 = 7",
                       sql_limit = 7),
    predict(fake_model,
            newdata = tbl,
            primary_key = "row_number",
            output_table = "score.table",
            output_db = "score_database",
            if_output_exists = "append",
            n_jobs = 10,
            polling_interval = 5,
            verbose = TRUE)
  )

  script_args <- mock_args(fake_scripts_post_custom)[[1]]
  expect_equal(script_args$from_template_id, 1111)
  expect_equal(script_args$name, "model_task Predict")

  # These are template args/params:
  pred_args <- script_args$arguments
  expect_is(pred_args, "AsIs")  # We don't want jsonlite doing anything unexpected.
  expect_equal(pred_args$TRAIN_JOB, 123)
  expect_equal(pred_args$TRAIN_RUN, 456)
  expect_equal(pred_args$PRIMARY_KEY, "row_number")
  expect_equal(pred_args$IF_EXISTS, "append")
  expect_equal(pred_args$N_JOBS, 10)
  expect_equal(pred_args$DEBUG, TRUE)
  expect_equal(pred_args$CIVIS_FILE_ID, NULL)
  expect_equal(pred_args$TABLE_NAME, "schema.table")
  expect_equal(pred_args$DB, list(database = 456))
  expect_equal(pred_args$WHERESQL, "6 = 7")
  expect_equal(pred_args$LIMITSQL, 7)
  expect_equal(pred_args$OUTPUT_TABLE, "score.table")
  expect_equal(pred_args$OUTPUT_DB, list(database = 456))

  # Make sure we started the job.
  expect_args(fake_scripts_post_custom_runs, 1, 999)

  # And checked it's status
  expect_args(fake_scripts_get_custom_runs, 1, 999, 888)
  expect_called(fake_scripts_get_custom_runs, 2)
})

test_that("uses training primary_key by default", {
  fake_get_database_id <- mock(123)
  fake_create_and_run_pred <- mock(NULL)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::create_and_run_pred` = fake_create_and_run_pred,

    tbl <- civis_table(table_name = "schema.table", database_name = "the_db"),
    predict(fake_model, newdata = tbl)
  )

  run_args <- mock_args(fake_create_and_run_pred)[[1]]
  expect_equal(run_args$primary_key, "training_primary_key")
})

test_that("uploads local df and passes a file_id", {
  fake_write_csv <- mock(NULL)
  fake_temp_file <- mock("fake_temp_path")
  fake_write_civis_file <- mock(1234)
  fake_create_and_run_pred <- mock(NULL)

  with_mock(
    `utils::write.csv` = fake_write_csv,
    `base::tempfile` = fake_temp_file,
    `civis::write_civis_file` = fake_write_civis_file,
    `civis::create_and_run_pred` = fake_create_and_run_pred,

    predict(fake_model, iris, primary_key = NULL)
  )

  expect_args(fake_write_csv, 1,
              iris,
              file = "fake_temp_path",
              row.names = FALSE)

  expect_args(fake_create_and_run_pred, 1,
              train_job_id = fake_model$job$id,
              train_run_id = fake_model$run$id,
              primary_key = NULL,
              output_table = NULL,
              output_db_id = NULL,
              if_output_exists = 'fail',
              model_name = "model_task",
              n_jobs = NULL,
              polling_interval = NULL,
              verbose = FALSE,
              file_id = 1234)
})

test_that("uploads a local file and passes a file_id", {
  fake_write_civis_file <- mock(561)
  fake_create_and_run_pred <- mock(NULL)

  with_mock(
    `civis::write_civis_file` = fake_write_civis_file,
    `civis::create_and_run_pred` = fake_create_and_run_pred,

    predict(fake_model, "fake_temp_path", primary_key = NULL)
  )

  expect_args(fake_write_civis_file, 1,
              "fake_temp_path",
              "modelpipeline_data.csv")

  expect_args(fake_create_and_run_pred, 1,
              train_job_id = fake_model$job$id,
              train_run_id = fake_model$run$id,
              primary_key = NULL,
              output_table = NULL,
              output_db_id = NULL,
              if_output_exists = 'fail',
              model_name = "model_task",
              n_jobs = NULL,
              polling_interval = NULL,
              verbose = FALSE,
              file_id = 561)
})

test_that("passes a file_id directly", {
  fake_create_and_run_pred <- mock(NULL)

  with_mock(
    `civis::create_and_run_pred` = fake_create_and_run_pred,

    predict(fake_model, civis_file(1234))
  )

  expect_args(fake_create_and_run_pred, 1,
              train_job_id = fake_model$job$id,
              train_run_id = fake_model$run$id,
              primary_key = "training_primary_key",
              output_table = NULL,
              output_db_id = NULL,
              if_output_exists = 'fail',
              model_name = "model_task",
              n_jobs = NULL,
              polling_interval = NULL,
              verbose = FALSE,
              file_id = 1234)
})

test_that("passes a manifest file_id", {
  fake_create_and_run_pred <- mock(NULL)

  with_mock(
    `civis::create_and_run_pred` = fake_create_and_run_pred,

    predict(fake_model, civis_file_manifest(123), primary_key = NULL)
  )

  expect_args(fake_create_and_run_pred, 1,
              train_job_id = fake_model$job$id,
              train_run_id = fake_model$run$id,
              primary_key = NULL,
              output_table = NULL,
              output_db_id = NULL,
              if_output_exists = 'fail',
              model_name = "model_task",
              n_jobs = NULL,
              polling_interval = NULL,
              verbose = FALSE,
              manifest = 123)
})

test_that("passes table info", {
  fake_get_database_id <- mock(999)
  fake_create_and_run_pred <- mock(NULL)

  with_mock(
    `civis::get_database_id` = fake_get_database_id,
    `civis::create_and_run_pred` = fake_create_and_run_pred,

    table_to_score <- civis_table(
      table_name = "a_schema.table",
      database_name = "a_database",
      sql_where = "row_number in (1, 2, 4)",
      sql_limit = 11
    ),
    predict(fake_model, table_to_score, primary_key = NULL)
  )

  expect_args(fake_get_database_id, 1, "a_database")
  expect_args(fake_create_and_run_pred, 1,
              train_job_id = fake_model$job$id,
              train_run_id = fake_model$run$id,
              primary_key = NULL,
              output_table = NULL,
              output_db_id = NULL,
              if_output_exists = 'fail',
              model_name = "model_task",
              n_jobs = NULL,
              polling_interval = NULL,
              verbose = FALSE,
              table_name = "a_schema.table",
              database_id = 999,
              sql_where = "row_number in (1, 2, 4)",
              sql_limit = 11)
})

################################################################################
# run build model
context("create_and_run_model")

test_that("uses the correct template_id", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = 123)
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(run_args$template_id, 999999)
})

test_that("converts parameters arg to JSON string", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = 123, parameters = list(n_trees = 500, c = -1))
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(unclass(run_args$arguments$PARAMS), '{"n_trees":500,"c":-1}')
})

test_that("converts cross_validation_parameters to JSON string", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = 123,
                         cross_validation_parameters = list(n_trees = c(500, 250), c = -1))
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(unclass(run_args$arguments$CVPARAMS),
               '{"n_trees":[500,250],"c":[-1]}')
})

test_that("converts fit_params to JSON string", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = 123,
                         fit_params = list(weights = "weight_col"))
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(unclass(run_args$arguments$FIT_PARAMS), '{"weights":"weight_col"}')
})

test_that("space separates excluded_columns", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = 132, excluded_columns = c("c1", "c2", "c3"))
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(run_args$arguments$EXCLUDE_COLS, "c1 c2 c3")
})

test_that("space separates target_column", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = 132, dependent_variable = c("c1", "c2"))
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(run_args$arguments$TARGET_COLUMN, "c1 c2")
})

test_that("file_id is always numeric", {
  fake_getOption <- mock(999999, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_civis_ml_fetch_existing <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::civis_ml_fetch_existing` = fake_civis_ml_fetch_existing,

    create_and_run_model(file_id = civis_file(132))
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(run_args$arguments$CIVIS_FILE_ID, 132)
})

################################################################################
# run predictions
context("create_and_run_pred")

test_that("uses the correct template_id", {
  fake_getOption <- mock(8888, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_fetch_predict_results <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::fetch_predict_results` = fake_fetch_predict_results,

    create_and_run_pred(train_job_id = 111, train_run_id = 222)
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(run_args$template_id, 8888)
})

test_that("adds resources when n_jobs = 1", {
  fake_getOption <- mock(8888, cycle = TRUE)
  fake_run_model <- mock(list(job_id = 133, run_id = 244))
  fake_fetch_predict_results <- mock(NULL)

  with_mock(
    `base::getOption` = fake_getOption,
    `civis::run_model` = fake_run_model,
    `civis::fetch_predict_results` = fake_fetch_predict_results,

    create_and_run_pred(train_job_id = 111, train_run_id = 222, n_jobs = 1)
  )

  run_args <- mock_args(fake_run_model)[[1]]
  expect_equal(run_args$arguments$REQUIRED_CPU, 1024)
  expect_equal(run_args$arguments$REQUIRED_MEMORY, 3000)
  expect_equal(run_args$arguments$REQUIRED_DISK_SPACE, 30)
})

###############################################################################
# logs
context("fetch_logs.civis_ml")

log_response <- list(
  list(
    id = 1147128844,
    createdAt = "2017-07-10T02:53:11.000Z",
    message = "Script complete.",
    level = "info"
  ),
  list(
    id = 1147128841,
    createdAt = "2017-07-10T02:53:11.000Z",
    message = "Process used approximately 83.28 MiB of its 3188 limit",
    level = "info"
  )
)

test_that("calls scripts_list_custom_runs_logs", {
  fake_scripts_list_custom_runs_logs <- mock(log_response)

  with_mock(
    `civis::scripts_list_custom_runs_logs` = fake_scripts_list_custom_runs_logs,

    fetch_logs(fake_model)
  )

  expect_args(fake_scripts_list_custom_runs_logs, 1,
              id = fake_model$job$id,
              run_id = fake_model$run$id,
              limit = 100)
})

test_that("formats the log messages", {
  Sys.setenv("TZ" = "CST6CDT")
  fake_scripts_list_custom_runs_logs <- mock(log_response)

  with_mock(
    `civis::scripts_list_custom_runs_logs` = fake_scripts_list_custom_runs_logs,

    messages <- fetch_logs(fake_model)
  )

  expected_messages <- structure(c(
    "2017-07-09 21:53:11 PM CDT Process used approximately 83.28 MiB of its 3188 limit",
    "2017-07-09 21:53:11 PM CDT Script complete."),
    class = "civis_logs")
  expect_equal(messages, expected_messages)

  Sys.unsetenv("TZ")
})

################################################################################
# fetch existing model
context("civis_ml_fetch_existing")

test_that("raises an error on not found", {
  fake_scripts_get_custom <- function(id) stop(httr::http_condition(404L, "error"))

  with_mock(
    `civis::scripts_get_custom` = fake_scripts_get_custom,

    expect_error(civis_ml_fetch_existing(123), "Error: model 123 not found\\.")
  )
})

test_that("raises an error on invalid model", {
  fake_must_fetch_civis_ml_job <- mock(
    list(
      lastRun = list(
        id = NULL
      )
    )
  )
  with_mock(
    `civis::must_fetch_civis_ml_job` = fake_must_fetch_civis_ml_job,

    expect_error(civis_ml_fetch_existing(123), "Error: invalid model task\\.")
  )
})

test_that("issues message for still running", {
  fake_must_fetch_civis_ml_job <- mock(
    list(
      lastRun = list(
        id = 456
      ),
      arguments = list(
          MODEL = "regressor"
        )
    )
  )
  fake_scripts_get_custom_runs <- mock(list(state = "running"))

  with_mock(
    `civis::must_fetch_civis_ml_job` = fake_must_fetch_civis_ml_job,
    `civis::scripts_get_custom_runs` = fake_scripts_get_custom_runs,

    expect_message(civis_ml_fetch_existing(123),
                   "The model task is still running\\.")
  )
})

test_that("raises an error if job failed", {
  fake_must_fetch_civis_ml_job <- mock(
    list(
      lastRun = list(
        id = 456
      ),
      arguments = list(
          MODEL = "regressor"
        )
      )
  )
  fake_scripts_get_custom_runs <- mock(list(state = "failed"))

  with_mock(
    `civis::must_fetch_civis_ml_job` = fake_must_fetch_civis_ml_job,
    `civis::scripts_get_custom_runs` = fake_scripts_get_custom_runs,

    expect_warning(civis_ml_fetch_existing(123),
                   "The model task failed, use fetch_logs to retreive any error messages.")
  )
})

###############################################################################
context("run_model")

test_that("it removes notifications when NULL", {
  fake_scripts_post_custom <- mock(list(id = 123))
  fake_scripts_post_custom_runs <- mock(list(id = 456))
  fake_scripts_get_custom_runs <- mock(list(state = "succeeded"))

  with_mock(
    `civis::scripts_post_custom` = fake_scripts_post_custom,
    `civis::scripts_post_custom_runs` = fake_scripts_post_custom_runs,
    `civis::scripts_get_custom_runs` = fake_scripts_get_custom_runs,

    run_model(template_id = 123, name = "a name", arguments = list(a = "b"),
              notifications = NULL, verbose = TRUE)
  )
  script_args <- mock_args(fake_scripts_post_custom)[[1]]
  expect_false("notifications" %in% names(script_args))
})

test_that("it removes name when NULL", {
  fake_scripts_post_custom <- mock(list(id = 123))
  fake_scripts_post_custom_runs <- mock(list(id = 456))
  fake_scripts_get_custom_runs <- mock(list(state = "succeeded", NULL))

  with_mock(
    `civis::scripts_post_custom` = fake_scripts_post_custom,
    `civis::scripts_post_custom_runs` = fake_scripts_post_custom_runs,
    `civis::scripts_get_custom_runs` = fake_scripts_get_custom_runs,

    run_model(template_id = 123, name = NULL, arguments = list(a = "b"),
              notifications = NULL, verbose = TRUE)
  )
  script_args <- mock_args(fake_scripts_post_custom)[[1]]
  expect_false("name" %in% names(script_args))
})

###############################################################################
context("fetch_oos_scores")

test_that("it checks input type", {
  fake_must_fetch_output_file <- mock(NULL)
  fake_read_csv <- mock(NULL)

  with_mock(
    `utils::read.csv` = fake_read_csv,
    `civis::must_fetch_output_file` = fake_must_fetch_output_file,

    expect_error(fetch_oos_scores("not a model"), "is_civis_ml(model) is not TRUE", fixed = TRUE)
  )
})

test_that("it looks for predictions.csv.gz", {
  fake_must_fetch_output_file <- mock(NULL)
  fake_read_csv <- mock(NULL)

  with_mock(
    `utils::read.csv` = fake_read_csv,
    `civis::must_fetch_output_file` = fake_must_fetch_output_file,

    fetch_oos_scores(structure(list(), class = "civis_ml"))
  )

  fetch_args <- mock_args(fake_must_fetch_output_file)[[1]]
  expect_equal(fetch_args[[2]], "predictions.csv.gz")
})

test_that("it calls read.csv with extra args", {
  fake_must_fetch_output_file <- mock("a_file.csv")
  fake_read_csv <- mock(NULL)

  with_mock(
    `utils::read.csv` = fake_read_csv,
    `civis::must_fetch_output_file` = fake_must_fetch_output_file,

    fetch_oos_scores(structure(list(), class = "civis_ml"), stringsAsFactors = FALSE)
  )

  csv_args <- mock_args(fake_read_csv)[[1]]
  expect_equal(csv_args[[1]], "a_file.csv")
  expect_equal(csv_args$stringsAsFactors, FALSE)
})
