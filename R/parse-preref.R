parse_preref <- function(x, file, offset = x[[1]]) {
  tags <- tokenise_preref(as.character(x), file = basename(file), offset = offset)
  if (length(tags) == 0)
    return()

  tags <- parse_description(tags)
  tags <- compact(lapply(tags, parse_tag))

  # Convert to existing named list format - this isn't ideal, but
  # it's what roxygen already uses
  vals <- lapply(tags, `[[`, "val")
  names <- vapply(tags, `[[`, "tag", FUN.VALUE = character(1))
  setNames(vals, names)
}

parse_description <- function(tags) {
  if (length(tags) == 0) {
    return(tags)
  }

  tag_names <- vapply(tags, `[[`, "tag", FUN.VALUE = character(1))
  if (tag_names[1] != "") {
    return(tags)
  }

  intro <- tags[[1]]
  tags <- tags[-1]
  tag_names <- tag_names[-1]

  paragraphs <- str_trim(str_split(intro$val, fixed('\n\n'))[[1]])

  # 1st paragraph = title (unless has @title)
  if ("title" %in% tag_names) {
    title <- NULL
  } else if (length(paragraphs) > 0) {
    title <- roxygen_tag("title", paragraphs[1], intro$file, intro$line)
    paragraphs <- paragraphs[-1]
  } else {
    title <- roxygen_tag("title", "", intro$file, intro$line)
  }

  # 2nd paragraph = description (unless has @description)
  if ("description" %in% tag_names) {
    description <- NULL
  } else if (length(paragraphs) > 0) {
    description <- roxygen_tag("description", paragraphs[1], intro$file, intro$line)
    paragraphs <- paragraphs[-1]
  } else {
    # Description is required, so if missing description, repeat title.
    description <- roxygen_tag("description", title$val, intro$file, intro$line)
  }

  # Every thing else = details, combined with @details
  if (length(paragraphs) > 0) {
    details_para <- paste(paragraphs, collapse = "\n\n")

    # Find explicit @details tags
    didx <- which(tag_names == "details")
    if (length(didx) > 0) {
      explicit_details <- vapply(tags[didx], `[[`, "val",
        FUN.VALUE = character(1))
      tags <- tags[-didx]
      details_para <- paste(c(details_para, explicit_details), collapse = "\n\n")
    }

    details <- roxygen_tag("details", details_para, intro$file, intro$line)
  } else {
    details <- NULL
  }

  c(compact(list(title, description, details)), tags)
}

parse_tag <- function(x) {
  stopifnot(is.roxygen_tag(x))

  if ((!x$tag %in% names(preref.parsers))) {
    return(tag_warning(x, "unknown tag"))
  }

  preref.parsers[[x$tag]](x)
}

# Individual tag parsers --------------------------------------------------

parse.value <- function(x) {
  if (x$val == "") {
    tag_warning(x, "requires a value")
  } else if (!rdComplete(x$val)) {
    tag_warning(x, "mismatched braces")
  } else {
    x
  }
}

# Examples need special parsing because escaping rules are different
parse.examples <- function(x) {
  if (x$val == "") {
    return(tag_warning(x, "requires a value"))
  }

  x$val <- escape_examples(gsub("^\n", "", x$val))
  if (!rdComplete(x$val, TRUE)) {
    tag_warning(x, "mismatched braces")
  } else {
    x
  }
}

words_parser <- function(min = 0, max = Inf) {
  function(x) {
    if (!rdComplete(x$val)) {
      return(tag_warning(x, "mismatched braces"))
    }

    words <- str_split(x$val, "\\s+")[[1]]
    if (length(words) < min) {
      tag_warning(x,  " needs at least ", min, " words")
    } else if (length(words) > max) {
      tag_warning(x,  " can have at most ", max, " words")
    }

    x$val <- words
    x
  }
}

parse.words.line <- function(x) {
  if (str_detect(x$val, "\n")) {
    tag_warning(x, "may only span a single line")
  } else if (!rdComplete(x$val)) {
    tag_warning(x, "mismatching braces")
  } else {
    x$val <- str_split(x$val, "\\s+")[[1]]
    x
  }
}

parse.name.description <- function(x) {
  if (x$val == "") {
    tag_warning(x, "requires a value")
  } else if (!str_detect(x$val, "[[:space:]]+")) {
    tag_warning(x, "requires name and description")
  } else if (!rdComplete(x$val)) {
    tag_warning(x, "mismatched braces")
  } else {
    pieces <- str_split_fixed(x$val, "[[:space:]]+", 2)

    x$val <- list(
      name = pieces[, 1],
      description = trim_docstring(pieces[, 2])
    )
    x
  }
}

parse.name <- function(x) {
  if (x$val == "") {
    tag_warning("requires a name")
  } else if (!rdComplete(x$val)) {
    tag_warning("mismatched braces")
  } else if (str_count(x$val, "\\s+") > 1) {
    tag_warning("should have only a single argument")
  } else {
    x
  }
}

parse.toggle <- function(x) {
  if (x$val != "") {
    tag_warning("has no parameters")
  } else {
    x
  }
}
