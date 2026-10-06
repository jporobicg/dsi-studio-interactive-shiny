a <- read.csv("outputs_main/dsi_all_windows.csv")
cat("MAIN: windows", nrow(a), " valid", sum(a$valid), "\n"); print(table(a$reasons_invalid, useNA="ifany"))
print(aggregate(cbind(dsi, dsi_v2, p_out, P_miss, p_inf, s_fit_e, s_stab) ~ species, a, function(x) round(median(x, na.rm=TRUE), 2), na.action = na.pass))
print(read.csv("outputs_main/dsi_best_window_selected.csv"))
## top by dsi (used for best_timeseries plot) vs selected by dsi_v2
for (g in unique(a$species)) { d <- a[a$species == g & is.finite(a$dsi), ]; d2 <- a[a$species == g & is.finite(a$dsi_v2), ]
  cat(g, ": best by DSI start", d$start_year[which.max(d$dsi)], "(", round(max(d$dsi),1), ") ; best by DSI_v2 start", d2$start_year[which.max(d2$dsi_v2)], "(", round(max(d2$dsi_v2),1), ")\n") }
cat("end_year unique per group (heatmap y axis):", tapply(a$end_year, a$species, function(x) length(unique(x))), "\n")
f <- read.csv("outputs/dsi_all_windows_fleet_species.csv")
cat("\nSPECIES x FLEET: groups", length(unique(f$group_key)), " windows", nrow(f), " valid", sum(f$valid), "; groups with >=1 valid window", length(unique(f$group_key[f$valid])), "\n")
cat("groups with no windows at all (span < min_n):", setdiff(unique(paste(read.csv('../Data/all_species_combined.csv')$species, read.csv('../Data/all_species_combined.csv')$gear, sep=' | ')), unique(f$group_key)), "\n")
q <- function(x) round(quantile(x, c(.1,.5,.9), na.rm=TRUE),1)
cat("DSI q10/50/90:", q(f$dsi), " DSI_v2:", q(f$dsi_v2), " s_drift (x100):", q(100*f$s_drift), "\n")
cat("share valid windows with s_drift == 0:", round(mean(f$s_drift[f$valid] < 1e-3, na.rm=TRUE), 2), "\n")
best <- do.call(rbind, lapply(split(f[is.finite(f$dsi_v2),], f$group_key[is.finite(f$dsi_v2)]), function(d) d[which.max(d$dsi_v2), c("group_key","start_year","end_year","dsi","dsi_v2")]))
best <- best[order(-best$dsi_v2),]; cat("best DSI_v2 per group; n >=70:", sum(best$dsi_v2>=70), " 50-70:", sum(best$dsi_v2>=50 & best$dsi_v2<70), " <50:", sum(best$dsi_v2<50), "\n"); print(head(best, 8), row.names=FALSE)
