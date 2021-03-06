% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dbi-driver.R
\name{dbi_driver}
\alias{dbi_driver}
\title{Civis DBI driver}
\usage{
dbi_driver()
}
\description{
This is a DBI-compliant interface for the Civis Platform.
}
\examples{
\dontrun{
con <- DBI::dbConnect(dbi_driver(), database = "redshift-general")
rs <- DBI::dbSendQuery(con, "SELECT 1")
dbFetch(rs)
}
}
