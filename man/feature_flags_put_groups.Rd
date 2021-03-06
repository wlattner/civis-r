% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/generated_client.R
\name{feature_flags_put_groups}
\alias{feature_flags_put_groups}
\title{Activate a feature for a group}
\usage{
feature_flags_put_groups(flag_name, group_id)
}
\arguments{
\item{flag_name}{string required. The feature flag name.}

\item{group_id}{integer required. Group ID.}
}
\value{
A list containing the following elements:
\item{name}{string, The name of the feature flag.}
\item{userCount}{integer, The number of users with this feature flag enabled.}
\item{description}{string, }
\item{team}{string, }
\item{jira}{string, }
\item{added}{string, }
\item{groupCount}{integer, }
\item{percentage}{integer, The target percentage of users who should have this feature flag enabled.}
}
\description{
Activate a feature for a group
}
