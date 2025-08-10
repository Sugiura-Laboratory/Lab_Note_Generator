# ============================================================
# Version    : 1.0.0
# Author     : Shuichi Sugiura
# Date       : 2025-08-09
# Code Name  : Wadden
# ------------------------------------------------------------
# Description:
#   This Shiny app automatically generates lab notes for psychology experiments.
#   When a participant ID is entered, it assigns Heartbeat Counting Task (HCT)
#   trial durations (e.g., 30, 45, 55 seconds) in a non-repeating order based
#   on a pre-prepared randomization list (randomization_list.csv).
#
#   Experiment details (participant ID, lab number, experimenter name,
#   start/end times) are recorded and output as:
#     - PDF or editable Rmd lab note
#     - UTF-8 BOM encoded CSV (Excel compatible on Windows/macOS)
#
#   All generated files are stored locally and are not uploaded online.
# ------------------------------------------------------------
# Notes:
#   - Participant ID is formatted as 3 digits (e.g., 001)
#   - Timestamps use "YYYY-MM-DD HH:MM" in JST
#   - randomization_list.csv is provided as a sample
# ============================================================

# app_labnote.R
library(shiny)
library(rmarkdown)
library(dplyr)
library(stringr)
library(readr)   # ← BOM/エンコーディングに強い読込用

# JST 現在時刻（YYYY-MM-DD HH:MM）
jst_now_str <- function() format(Sys.time(), "%Y-%m-%d %H:%M", tz = "Asia/Tokyo")

ui <- fluidPage(
  titlePanel("Lab note"),
  sidebarLayout(
    sidebarPanel(
      width = 4,
      h4("実験情報の入力"),
      textInput("lab_number", "実験室番号:", placeholder = "例：A-101"),
      textInput("experimenter_name", "実験者名（表に出力）:", placeholder = "例：杉浦"),
      hr(),
      textInput("subject_id", "被験者ID:", placeholder = "例：1"),
      hr(),
      h4("実験手順"),
      p(strong("1. Heartbeat Counting Task")),
      p(strong("2. Experiment (Computer)")),
      p(strong("3. Questionnaire (Computer)")),
      hr(),
      h4("Heartbeat Counting Task (HCT)"),
      p("被験者IDに応じて，HCT のカウンターバランス順序が自動で表示されます。"),
      tags$div(
        style = "font-size: 1.2em; color: blue; margin-bottom: 10px; border: 1px solid #ccc; padding: 10px; border-radius: 5px;",
        htmlOutput("assigned_task_order")
      ),
      hr(),
      fluidRow(
        column(8, textInput("start_time", "実験開始（JST, YYYY-MM-DD HH:MM）:", value = jst_now_str())),
        column(4, style = "margin-top: 25px;", actionButton("timestamp_start", "現在"))
      ),
      fluidRow(
        column(8, textInput("end_time", "実験終了（JST, YYYY-MM-DD HH:MM）:", value = jst_now_str())),
        column(4, style = "margin-top: 25px;", actionButton("timestamp_end", "現在"))
      ),
      hr(),
      checkboxInput("generate_pdf", "PDFを生成する", value = TRUE),
      helpText("チェックを外すと、編集用 .Rmd を保存します（Rmd のタイトル/著者は Rmd で編集）。"),
      hr(),
      actionButton("generate_files", "レポート生成", class = "btn-primary btn-lg"),
      hr(),
      helpText(strong("App Info")),
      helpText("Version: 1.0.0"),
      helpText("Author: Shuichi Sugiura"),
      helpText("Code Name: Wadden"),
      helpText("Date: 2025-08-09")
    ),
    mainPanel(
      width = 8,
      h3("生成結果プレビュー（CSVの内容）"),
      tableOutput("result_table")
    )
  )
)

server <- function(input, output, session) {
  
  observeEvent(input$timestamp_start, { updateTextInput(session, "start_time", value = jst_now_str()) })
  observeEvent(input$timestamp_end,   { updateTextInput(session, "end_time",   value = jst_now_str()) })
  
  # --- ランダマイゼーション表の読み込み（BOM/列名ゆらぎに強い） ---
  validate_rand_list <- reactive({
    path <- "randomization_list.csv"
    if (!file.exists(path)) stop("randomization_list.csv が見つかりません。リポジトリ直下に配置してください。")
    
    # 1) readr を優先（BOMや型の扱いが堅牢）
    df <- tryCatch(
      {
        suppressWarnings(readr::read_csv(path, show_col_types = FALSE, locale = readr::locale(encoding = "UTF-8")))
      },
      error = function(e) {
        # 2) フォールバック（base R。UTF-8-BOM を明示）
        read.csv(path, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE, check.names = FALSE)
      }
    )
    
    # 列名のBOM/空白/大小文字の揺れを吸収
    nm <- names(df)
    nm <- sub("^\ufeff", "", nm)  # 先頭BOM除去
    nm <- trimws(nm)
    names(df) <- nm
    
    # ID列の同定（id / subject_id / participant なども許容）
    id_candidates <- tolower(names(df))
    id_idx <- which(id_candidates %in% c("id","subject_id","participant","participant_id"))[1]
    if (is.na(id_idx)) stop("randomization_list.csv に ID 列が見つかりません（例: ID, subject_id）。")
    names(df)[id_idx] <- "ID"
    
    # 3桁ゼロ埋めのIDへ正規化
    df$ID <- sprintf("%03d", as.integer(stringr::str_extract(df$ID, "\\d+")))
    
    # Trial列の取得（t1/t2/t3 などの省略表記にも軽く対応）
    tl <- tolower(names(df))
    t1 <- names(df)[which(tl %in% c("trial1","t1"))[1]]
    t2 <- names(df)[which(tl %in% c("trial2","t2"))[1]]
    t3 <- names(df)[which(tl %in% c("trial3","t3"))[1]]
    if (any(is.na(c(t1,t2,t3)))) stop("randomization_list.csv に Trial1〜Trial3 列が見つかりません。")
    df[[t1]] <- as.integer(df[[t1]])
    df[[t2]] <- as.integer(df[[t2]])
    df[[t3]] <- as.integer(df[[t3]])
    
    dplyr::rename(df, Trial1 = !!t1, Trial2 = !!t2, Trial3 = !!t3)
  })
  
  # HCT 順序（例: 45 秒 → 55 秒 → 30 秒）
  assigned_order_formatted <- reactive({
    req(input$subject_id)
    id_num_str <- stringr::str_extract(input$subject_id, "\\d+")
    if (is.na(id_num_str)) return(NULL)
    id3 <- sprintf("%03d", as.integer(id_num_str))
    
    rl <- validate_rand_list()
    matched <- dplyr::filter(rl, ID == id3)
    if (nrow(matched) == 1) {
      paste0(matched$Trial1, " 秒 → ", matched$Trial2, " 秒 → ", matched$Trial3, " 秒")
    } else NULL
  })
  
  output$assigned_task_order <- renderUI({
    ord <- assigned_order_formatted()
    if (!is.null(ord)) HTML(paste("<b>HCT順序:</b>", ord))
    else HTML("<span style='color: red;'>IDがリストに存在しません</span>")
  })
  
  # LaTeX 無害化（ファイル出力用）
  sanitize_latex <- function(x) {
    if (is.null(x)) return(NULL)
    x <- gsub("\\\\", "\\\\textbackslash{}", x)
    x <- gsub("([{}])", "\\\\\\1", x, perl = TRUE)
    x <- gsub("_", "\\\\_", x, fixed = TRUE)
    x <- gsub("%", "\\\\%", x, fixed = TRUE)
    x <- gsub("\\$", "\\\\$", x)
    x <- gsub("&", "\\\\&", x, fixed = TRUE)
    x <- gsub("#", "\\\\#", x, fixed = TRUE)
    x <- gsub("\\^", "\\\\textasciicircum{}", x)
    x <- gsub("~", "\\\\textasciitilde{}", x)
    x
  }
  
  observeEvent(input$generate_files, {
    tryCatch({
      withProgress(message = 'レポートを生成中', value = 0, {
        ord <- assigned_order_formatted()
        if (is.null(ord)) stop("有効な被験者IDがリストに見つかりません。")
        
        # ID（3 桁）
        id_num <- as.integer(stringr::str_extract(input$subject_id, "\\d+"))
        id3 <- sprintf("%03d", id_num)
        
        # 命名: labnote_ID-<3桁>_<YYYYMMDD-HHMM>
        ts_tag <- format(Sys.time(), "%Y%m%d-%H%M", tz = "Asia/Tokyo")
        base_filename <- sprintf("labnote_ID-%s_%s", id3, ts_tag)
        
        # CSV（UTF-8 + BOM、Win/Mac 両対応）
        incProgress(0.33, detail = "CSV を書き出し中...")
        csv_file_path <- paste0(base_filename, ".csv")
        output_data <- data.frame(
          ID = id3,
          ExperimentOrder = "Heartbeat Counting Task → Experiment → Questionnaire",
          HCT_Order = ord,
          StartDateTime_JST = input$start_time,  # YYYY-MM-DD HH:MM（JST）
          EndDateTime_JST   = input$end_time,
          LabNumber = input$lab_number,
          Experimenter = input$experimenter_name,
          stringsAsFactors = FALSE
        )
        # 新規に BOM を書き、続けて CSV を追記（BOM を保持）
        con <- file(csv_file_path, open = "wb")
        writeBin(charToRaw('\ufeff'), con)  # BOM
        close(con)
        write.table(
          output_data, csv_file_path, sep = ",",
          row.names = FALSE, col.names = TRUE,
          fileEncoding = "UTF-8", append = TRUE, qmethod = "double"
        )
        
        # Rmd へ渡す params（タイトル/著者は Rmd で編集。表の実験者名は Shiny 入力）
        incProgress(0.66, detail = "Rmd 用パラメータ準備中...")
        params <- list(
          subject_id        = id3,
          experiment_order  = "Heartbeat Counting Task → Experiment → Questionnaire",
          start_time        = input$start_time,
          end_time          = input$end_time,
          lab_number        = sanitize_latex(input$lab_number),
          hct_order         = sanitize_latex(ord),
          output_timestamp  = jst_now_str(),
          experimenter_name = sanitize_latex(input$experimenter_name)
        )
        
        # 出力
        incProgress(1, detail = "レポートを出力中...")
        generated_file <- ""
        
        if (isTRUE(input$generate_pdf)) {
          pdf_file_path <- paste0(base_filename, ".pdf")
          rmarkdown::render(
            input = "labnote_template.Rmd",
            output_file = pdf_file_path,
            params = params,
            envir = new.env(parent = globalenv())
          )
          generated_file <- pdf_file_path
        } else {
          # 編集用 Rmd（YAML の date は固定文字列で埋め込む）
          rmd_file_path <- paste0(base_filename, ".Rmd")
          template <- readLines("labnote_template.Rmd", warn = FALSE, encoding = "UTF-8")
          yaml_end_index <- which(template == "---")[2]
          rmd_body <- template[(yaml_end_index + 1):length(template)]
          date_str <- format(Sys.Date(), "%Y-%m-%d")
          
          new_yaml <- sprintf(
            '---
title: "研究課題名（ここに入力）"
author: "作成者名（ここに入力）"
date: "%s"
output:
  pdf_document:
    latex_engine: lualatex
    toc: false
    number_sections: false
header-includes: |
  \\usepackage{luatexja}
  \\usepackage{luatexja-fontspec}
  \\setmainfont{IPAexMincho}
  \\usepackage{geometry}
  \\geometry{a4paper, left=2cm, right=2cm, top=2.5cm, bottom=2.5cm}
  \\usepackage{fancyhdr}
  \\setlength{\\headheight}{14pt}
  \\fancyhf{}
  \\lhead{実験実施記録}
  \\rhead{Report Generated: \\texttt{`r params$output_timestamp`}}
  \\cfoot{\\thepage}
  \\renewcommand{\\headrulewidth}{0.4pt}
  \\renewcommand{\\footrulewidth}{0.4pt}
  \\usepackage{booktabs}
  \\usepackage{tabularx}
  \\pagestyle{fancy}
  \\fancypagestyle{plain}{
    \\fancyhf{}
    \\lhead{実験実施記録}
    \\rhead{Report Generated: \\texttt{`r params$output_timestamp`}}
    \\cfoot{\\thepage}
    \\renewcommand{\\headrulewidth}{0.4pt}
    \\renewcommand{\\footrulewidth}{0.4pt}
  }
params:
  subject_id: "%s"
  experiment_order: "%s"
  start_time: "%s"
  end_time: "%s"
  lab_number: "%s"
  hct_order: "%s"
  output_timestamp: "%s"
  experimenter_name: "%s"
---',
            date_str,
            params$subject_id, params$experiment_order, params$start_time,
            params$end_time, params$lab_number, params$hct_order,
            params$output_timestamp, params$experimenter_name
          )
          
          writeLines(c(new_yaml, rmd_body), rmd_file_path, useBytes = TRUE)
          generated_file <- rmd_file_path
        }
        
        output$result_table <- renderTable(output_data)
        showModal(modalDialog(
          title = "生成完了！",
          paste(generated_file, "と", csv_file_path, "が保存されました。"),
          easyClose = TRUE, footer = NULL
        ))
      })
    }, error = function(e) {
      showModal(modalDialog(
        title = "エラーが発生しました",
        tags$b("PDF/Rmd の生成に失敗しました。以下のメッセージを確認してください："),
        hr(),
        tags$pre(conditionMessage(e))
      ))
    })
  })
}

shinyApp(ui = ui, server = server)
