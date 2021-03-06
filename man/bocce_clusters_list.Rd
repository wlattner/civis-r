% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/generated_client.R
\name{bocce_clusters_list}
\alias{bocce_clusters_list}
\title{List Bocce Clusters}
\usage{
bocce_clusters_list(organization_id = NULL, limit = NULL, page_num = NULL,
  order = NULL, order_dir = NULL)
}
\arguments{
\item{organization_id}{integer optional. The ID of the organization to list clusters for.}

\item{limit}{integer optional. Number of results to return. Defaults to 50. Maximum allowed is 1000.}

\item{page_num}{integer optional. Page number of the results to return. Defaults to the first page, 1.}

\item{order}{string optional. The field on which to order the result set. Defaults to id. Must be one of: id, created_at.}

\item{order_dir}{string optional. Direction in which to sort, either asc (ascending) or desc (descending) defaulting to asc.}
}
\value{
An array containing the following fields:
\item{id}{integer, The ID of this cluster.}
\item{instanceType}{string, The EC2 instance types in this cluster.}
\item{minInstances}{integer, The minimum number of instances in this cluster.}
\item{maxInstances}{integer, The maximum number of instances in this cluster.}
\item{region}{string, The AWS region that this cluster is in.}
\item{activeJobsCount}{integer, The number of jobs currently being run in the cluster.}
\item{queuedJobsCount}{integer, The number of jobs currently waiting to be run on the cluster.}
\item{organizationIds}{array, The ids of this cluster's organizations.}
\item{organizationSlugs}{array, The slugs of this cluster's organizations.}
\item{singleOrg}{boolean, Whether this cluster is allowed to be used by multiple orgs.}
\item{desiredInstances}{integer, The number of instances this cluster should attempt to have.}
\item{createdAt}{string, The date and time of cluster creation.}
\item{updatedAt}{string, The date and time of the cluster's last update.}
}
\description{
List Bocce Clusters
}
