library(pdftools)

pdfs_list <- list.files("reports_pdf", pattern = "pdf$")
pdfs_list

rep1_pdf_text <- pdf_text("reports_pdf/StaffDoses_1.pdf")
rep1_pdf_text

textConnection(rep1_pdf_text)

rep1_text <- scan(textConnection(rep1_pdf_text), what = "character", sep = "\n")
str(rep1_text)
rep1_text[2]

rep1_colnames <- unlist(strsplit(rep1_text[1], " \\s+"))
rep1_line1 <- t(unlist(strsplit(rep1_text[2], " \\s+")))
rep1_line2 <- t(unlist(strsplit(rep1_text[3], " \\s+")))
rep1_line4 <- t(unlist(strsplit(rep1_text[5], " \\s+")))
data.frame(rbind(rep1_line1, rep1_line2))


rep1 <- data.frame(matrix(ncol = length(rep1_colnames), nrow = 0))
colnames(rep1) <- rep1_colnames
rep1



for (i in 2:length(rep1_text)){
  rep1 <- rbind(rep1, t(unlist(strsplit(rep1_text[i], " \\s+"))))
}
data.frame(rep1)
rep1 <- rep1[,-1]

colnames(rep1) <- rep1_colnames
