;; Share-class groups: tickers that are live share classes of ONE issuer.
;;
;; Read by Share_class_map.load (trading/trading/weinstein/strategy/lib/)
;; when the strategy's one-share-class-per-issuer flag is on
;; (issue #3015, default off). With the flag on, a long entry candidate is
;; skipped while another class of its group is held or has a pending entry.
;;
;; One group per line, first ticker = group id. A ticker may appear in at most
;; one group, and every group needs >= 2 tickers (the loader fails otherwise).
;;
;; Seed list grepped from the committed PIT top-3000 union; NOT exhaustive.
;; IAC/MTCH is deliberately absent: a spin-off, not a share-class pair (#2782).
((GOOG GOOGL)
 (BRK-A BRK-B)
 (FOX FOXA)
 (NWS NWSA)
 (UA UAA)
 (LBRDA LBRDK)
 (LEN LEN-B)
 (HEI HEI-A)
 (BF-A BF-B)
 (LSXMA LSXMK)
 (FWONA FWONK)
 (Z ZG)
 (CMCSA CMCSK)
 (CWEN CWEN-A)
 (LBTYA LBTYK)
 (LILA LILAK)
 (LGF-A LGF-B)
 (STZ STZ-B)
 (UHAL UHAL-B)
 (BELFA BELFB)
 (CENT CENTA)
 (PBR PBR-A)
 (EBR EBR-B)
 (AKO-A AKO-B))
