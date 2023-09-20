#' FWL Plot
#'
#' This function creates a bivariate plot of `y` and `x` after residualizing over a set of covariates `w`.
#'
#' @param fml Of the form `y ~ x + covs | fes` following the fixest formula syntax. The x variable you want plotted should come first.
#' @param data A `dataframe` object that contains the variables in `fml`.
#' @param ggplot Boolean. Default is to use base R plot but if TRUE, use ggplot.
#'
#' @examples
#' fwl_plot(mpg ~ hp + wt | cyl, mtcars)
#'
#' library(ggplot2)
#' fwl_plot(mpg ~ hp + wt | cyl, mtcars, ggplot = TRUE) +
#'   theme_minimal()
#'
#' @return Either NULL if `ggplot = FALSE` or a ggplot object if `ggplot = TRUE`.
#'
#' @export
fwl_plot <- function(fml, data, ggplot = FALSE) {
  # main_est = feols(
  #   fml, data, notes = FALSE,
  # )

  # Reset
  fixest::setFixest_fml(..fwl_plot_FE = ~1, reset = TRUE)
  fixest::setFixest_fml(..fwl_plot_x = ~1, reset = TRUE)
  fixest::setFixest_fml(..fwl_plot_w = ~1, reset = TRUE)
  fixest::setFixest_fml(..fwl_plot_y = ~1, reset = TRUE)

  ## Process formula -----------------------------------------------------------
  parts = get_fml_parts(fml)

  fixest::setFixest_fml(..fwl_plot_y = parts$y_fml)
  
  has_fe = !is.null(parts$W_FE)
  if (has_fe == TRUE) {
    fixest::setFixest_fml(..fwl_plot_FE = parts$W_FE)
  }

  covs <- fml_breaker(parts$W_lin, "+")
  has_w <- (length(covs) > 1)
  if (has_w == TRUE) {
    n_covs <- length(covs)
    fixest::setFixest_fml(..fwl_plot_x = covs[[n_covs]])
    fixest::setFixest_fml(
      ..fwl_plot_w =
        paste(utils::head(covs, n_covs - 1), collapse = " + ")
    )
  } else {
    fixest::setFixest_fml(..fwl_plot_x = covs[[1]])
  }

  ## Create formula ------------------------------------------------------------
  if (has_w & has_fe) {
    fml <- fixest::xpd(
      c(..fwl_plot_y, ..fwl_plot_x) ~ ..fwl_plot_w | ..fwl_plot_FE
    )
    title <- paste(
      "Residualized by ~",
      as.character(fixest::xpd(~ ..fwl_plot_w | ..fwl_plot_FE))[[2]]
    )
  } else if (has_w) {
    fml <- fixest::xpd(
      c(..fwl_plot_y, ..fwl_plot_x) ~ ..fwl_plot_w
    )
    title <- paste(
      "Residualized by ~ ",
      as.character(fixest::xpd(~..fwl_plot_w))[[2]]
    )
  } else {
    fml <- fixest::xpd(
      ..fwl_plot_y ~ 0 + ..fwl_plot_x
    )
    title <- "Raw scatter plot"
  }

  ## Residualize ---------------------------------------------------------------
  should_run_reg <- has_w | has_fe
  if (should_run_reg) {
    est <- fixest::feols(
      fml = fml,
      data = data,
      notes = FALSE
    )

    if (length(est[[1]]$obs_selection) > 0) {
      y_resid <- numeric(length = nrow(data))
      y_resid[est[[1]]$obs_selection[[1]]] <- est[[1]]$resid
    } else {
      y_resid <- est[[1]]$resid
    }
    if (length(est[[2]]$obs_selection) > 0) {
      x_resid <- numeric(length = nrow(data))
      x_resid[est[[2]]$obs_selection[[1]]] <- est[[2]]$resid
    } else {
      x_resid <- est[[2]]$resid
    }
  } else {
    est <- fixest::feols(fml, data, notes = FALSE)
    x_resid <- as.numeric(stats::model.matrix(est, type = "rhs"))
    y_resid <- as.numeric(stats::model.matrix(est, type = "lhs"))
  }


  ## Plot ----------------------------------------------------------------------
  df <- data.frame(
    `y_resid` = y_resid,
    `x_resid` = x_resid
  )
  var_names <- c(
    y = as.character(fixest::xpd(~..fwl_plot_y))[[2]],
    x = as.character(fixest::xpd(~..fwl_plot_x))[[2]]
  )

  if (ggplot == FALSE) {
    
    df = df[order(df$x_resid), ]
    pred = stats::predict(stats::lm(y_resid ~ x_resid, data = df), newdata = df, interval = "confidence") 
    df = cbind(df, pred)
    
    # set up graphics device and window for new plot
    graphics::plot.new()
    graphics::plot.window(xlim = range(df$x_resid), ylim = range(df$lwr, df$upr, df$y_resid))
  
    # add background grid
    graphics::grid()
    
    # residualized data points
    graphics::points(
	    x = df$x_resid, y = df$y_resid,
	    pch = 19, col = grDevices::adjustcolor("black", 0.5),
    )
    
    # best of fit line and CI
    graphics::polygon(
	    c(df$x_resid, rev(df$x_resid)), c(df$lwr, rev(df$upr)),
	    col = grDevices::adjustcolor("gray", 0.3), border = NA
    )
    graphics::lines(df$x_resid, y = df$fit, lwd = 2, col = "blue")
    
    # axes: Add 'col = NA' args if you just want the ticks labels with no lines
    graphics::axis(1)
    graphics::axis(2, las = 2) 
    # plot frame: You might want to comment this out if you drop the axis lines
    box()
    
    graphics::title(title, adj = 0)
    graphics::title(xlab = var_names[2], ylab = var_names[1])
    
    invisible(NULL)

  } else {
    plot <- ggplot2::ggplot(
      df,
      mapping = ggplot2::aes(x = x_resid, y = y_resid)
    ) +
      ggplot2::geom_point() +
      ggplot2::geom_smooth(
        formula = y ~ x,
        method = "lm",
        color = "blue", linewidth = 1.2
      ) +
      ggplot2::labs(
        x = var_names["x"],
        y = var_names["y"],
        title = title
      )

    return(plot)
  }
}