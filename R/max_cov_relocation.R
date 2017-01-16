#' Maximum Coverage when considering relocation
#'
#' This function adds a relocation step
#'
#' @param existing_facility data.frame containing the facilities that are already in existing, with columns names lat, and long.
#' @param proposed_facility data.frame containing the facilities that are being proposed, with column names lat, and long.
#' @param user data.frame containing the users of the facilities, along with column names lat, and long.
#' @param distance_cutoff numeric indicating the distance cutoff (in metres)
#' you are interested in. If a number is less than distance_cutoff, it will be
#' 1, if it is greater than it, it will be 0.
#' @param n_added the maximum number of facilities to add.
#' @param n_solutions Number of possible solutions to return. Default is 1.
#' @param solver character default is lpSolve, but currently in development is a Gurobi solver, see issue #25 : \url{https://github.com/njtierney/maxcovr/issues/25}
#' @param cost_install integer the cost of installing a new facility
#' @param cost_relocate integer the cost of relocating a new facility
#' @param cost_total integer the total cost allocated to the project
#'
#' @return dataframe of results
#'
#' @export

max_coverage_relocation <- function(existing_facility = NULL,
                                    proposed_facility,
                                    user,
                                    distance_cutoff,
                                    n_added,
                                    n_solutions = 1,
                                    cost_install, # = NULL?
                                    cost_relocate, # = NULL?
                                    cost_total, # = NULL?
                                    solver = "lpSolve"){

# the A matrix that I feed here will be the combination of the
# existing AED locations and the potential AED locations.



# test data set using fake data ....
    #     library(dplyr)
    #
    #     existing_facility =  matrix(data = c(0, 0,
    #                                          0, 1,
    #                                          0, 0,
    #                                          1, 0,
    #                                          1, 0,
    #                                          0, 1),
    #                                 nrow = 6,
    #                                 ncol = 2,
    #                                 byrow = TRUE)
    #
    #     proposed_facility = matrix(data = c(1, 0, 0, 0, 0,
    #                                         0, 1, 1, 0, 0,
    #                                         0, 0, 0, 1, 1,
    #                                         1, 1, 0, 0, 0,
    #                                         0, 1, 0, 0, 0,
    #                                         0, 0, 1, 1, 0),
    #                                nrow = 6,
    #                                ncol = 5,
    #                                byrow = TRUE)
    #     # user = york_crime
    #     distance_cutoff = 100
    #     n_added = nrow(existing_facility) # should be #AEDs, # existing facilities
    #     n_solutions = 1
    #     cost_install = 5000
    #     cost_relocate = 200
    #     cost_total = 10^6 # some super large cost
    #
    # A <- cbind(existing_facility, proposed_facility)
    #
    # A

# end testing with fake data....

#

    # a little utility function to take the data and then get the lat/long
    # out and call as.matrix on it

    mc_mat_prep <- function(data){
        dplyr::select(data,lat,long) %>%
            as.matrix()
    }

    existing_facility_cpp <-
        binary_matrix_cpp(facility = mc_mat_prep(existing_facility),
                          user = mc_mat_prep(york_crime),
                          distance_cutoff = 100)

    proposed_facility_cpp <-
        binary_matrix_cpp(facility = mc_mat_prep(proposed_facility),
                          user = mc_mat_prep(york_crime),
                          distance_cutoff = 100)

    A <- cbind(
        existing_facility_cpp,
        proposed_facility_cpp
    )


Nx <- nrow(A)

# Nx

Ny <- ncol(A)

facility_names <- sprintf("facility_id_%s",
                          c(1:(nrow(existing_facility) + nrow(proposed_facility))))

colnames(A) <- facility_names

# hang on to the list of OHCA ids
# user_id_list <- A[,"user_id"]

user_id_list <- 1:nrow(user)

# Ny
n_added = nrow(existing_facility)

N <- n_added

# N

# N <- n_added[i]

c <- c(rep(0, Ny), rep(1,Nx))

# c

d <- c(rep(1, Ny), rep(0,Nx))

# d

Aeq <- d

# Aeq

# this is a line to optimise with cpp
Ain <- cbind(-A, diag(Nx))

# Ain

# create the m vector ----------------------------------------------------------

# I will also have the m vector, which will have some parameters like
# cost of installation
# cost of removal + relocation
# this can then be created inside the function

# identify the existing cols from the proposed cols
# which_existing <- c(
#     rep("existing", nrow(existing_facility)),
#     rep("proposed", nrow(proposed_facility))
# )

# this is the vector of costs, which will have the length
# of the number of rows of y
# plus the number of x's as 0s

# if using the testing data

# these are for the testing data
    # m_vec <- c(
    #     rep(cost_relocate*-1, ncol(existing_facility)),
    #     rep(cost_install, ncol(proposed_facility)),
    #     rep(0, Nx)
    # )


m_vec <- c(
    # these two are for the real data
    rep(cost_relocate*-1, ncol(existing_facility_cpp)),
    rep(cost_install, ncol(proposed_facility_cpp)),
    rep(0, Nx)
)

m_vec

# ------------------------

# matrix of numeric constraint coefficients,
# one row per constraint
# one column per variable
constraint_matrix <- rbind(Ain,
                           m_vec,
                           Aeq)

constraint_matrix

bin <- matrix(rep(0,Nx), ncol = 1)

bin

# this is sum_{i = 1}^I
sum_c_mi <- cost_total - abs(sum(m_vec[m_vec<0]))

sum_c_mi

beq <- N

beq

rhs_matrix <- rbind(bin,
                    sum_c_mi,
                    beq)

rhs_matrix

# this is another line to optimise with c++
constraint_directions <- c(rep("<=", Nx),
                           "<=",
                           ">=")

tail(constraint_directions)
# }) # end profvis

constraint_directions

# optim_result_box[[i]] <-
# for the york data, it takes 0.658 seconds
lp_solution <- lpSolve::lp(direction = "max",
                           # objective.in = d, # as of 2016/08/19
                           objective.in = c,
                           const.mat = constraint_matrix,
                           const.dir = constraint_directions,
                           const.rhs = rhs_matrix,
                           transpose.constraints = TRUE,
                           # int.vec,
                           # presolve = 0,
                           # compute.sens = 0,
                           # binary.vec,
                           # all.int = FALSE,
                           all.bin = TRUE,
                           # scale = 196,
                           # dense.const,
                           num.bin.solns = n_solutions,
                           use.rw = TRUE)

# determing the users not covered

dat_nearest_dist <- nearest_facility_dist(facility = mc_mat_prep(existing_facility),
                                          user = mc_mat_prep(user))

# make nearest dist into dataframe
# leave only those not covered
dat_nearest_no_cov <- dat_nearest_dist %>%
    dplyr::as_data_frame() %>%
    dplyr::rename(user_id = V1,
                  facility_id = V2,
                  distance = V3) %>%
    dplyr::filter(distance > distance_cutoff) # 100m is distance_cutoff

# give user an index
user <- user %>% dplyr::mutate(user_id = 1:n())

# join them, to create the "not covered" set of data
user_not_covered <- dat_nearest_no_cov %>%
    dplyr::left_join(user,
                     by = "user_id")

# / end determining users not covered

x <- list(
    # #add the variables that were used here to get more info
    existing_facility = existing_facility,
    proposed_facility = proposed_facility,
    distance_cutoff = distance_cutoff,
    existing_user = user,
    user_not_covered = user_not_covered,
    # dist_indic = dist_indic,
    n_added = n_added,
    n_solutions = n_solutions,
    A = A,
    user_id = user_id_list,
    lp_solution = lp_solution,
    cost_install = cost_install,
    cost_relocate = cost_relocate,
    cost_total = cost_total
)

# return(x)

model_result <- extract_mc_results_relocation(x)

return(model_result)

} # end function