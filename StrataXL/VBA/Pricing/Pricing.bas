Attribute VB_Name = "Pricing"

'====================================='
' Copyright (C) 2019 Tommaso Belluzzo '
'          Part of StrataXL           '
'====================================='

Option Explicit

Private Function PrepareCashFlows(ByVal wsCurrent As Worksheet) As Worksheet

    On Error Resume Next

    Dim wsCashFlows As Worksheet: Set wsCashFlows = ThisWorkbook.Sheets("Cash Flows")
    
    On Error GoTo 0

    If Not wsCashFlows Is Nothing Then
        
        Dim alerts As Boolean: alerts = Application.DisplayAlerts
    
        Application.DisplayAlerts = False
        wsCashFlows.Delete
        Application.DisplayAlerts = alerts

    End If

    Set wsCashFlows = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.Count))
    
    With wsCashFlows.Cells
        .Font.Name = "Calibri"
        .Font.Size = 10
        .Interior.Color = 15132391
        .Style.HorizontalAlignment = xlHAlignCenter
        .Style.VerticalAlignment = xlCenter
    End With
    
    wsCashFlows.Name = "Cash Flows"
    wsCashFlows.Tab.Color = 11573124

    wsCurrent.Activate

    Set PrepareCashFlows = wsCashFlows

End Function

Public Sub PricingFxNonDeliverable()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("FX Non-Deliverable")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count
    
    Dim i As Long, j As Long
    
    If (rc <= 1) Then
        Exit Sub
    Else
        For i = 2 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i
    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)
    
    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1

    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.fx.FxNdfTradeCalculations", "DEFAULT")

    For i = 2 To rc

        If (DateDiff("d", refValuationDate, ws.Cells(i, 6).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxNonDeliverable", "The trade " & CStr(i - 1) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        If (DateDiff("d", ws.Cells(i, 7).Value2, ws.Cells(i, 6).Value2) >= 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxNonDeliverable", "The trade " & CStr(i - 1) & " must have a maturity date greater than the trade date.")
        End If

        If (ws.Cells(i, 3).Value2 = ws.Cells(i, 4).Value2) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxNonDeliverable", "The trade " & CStr(i - 1) & " must be defined on different currencies.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim direction As Variant: direction = dd.GetDirection("A" & iText, False)
        Dim notional As Double: notional = dd.GetAmount("B" & iText)
        Dim ccySettlement As Variant: Set ccySettlement = dd.GetCurrency("C" & iText)
        Dim ccyNonDeliverable As Variant: Set ccyNonDeliverable = dd.GetCurrency("D" & iText)
        Dim rate As Double: rate = dd.GetRate("E" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("F" & iText)
        Dim maturityDate As Variant: Set maturityDate = dd.GetDate("G" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("H" & iText)

        If (direction = "BUY") Then
            notional = -notional
        End If
        
        Dim ccyPair As Variant: Set ccyPair = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.CurrencyPair", "of", ccySettlement, ccyNonDeliverable)
        Dim ccyPairName As String: ccyPairName = Replace$(UCase$(host.InvokeMethod(ccyPair, "toString")), "/", "-")

        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)
        Set maturityDate = host.InvokeMethod(bda, "adjust", maturityDate, dd.ReferenceData)

        Dim calendarSettlement As Variant: Set calendarSettlement = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.HolidayCalendarId", "defaultByCurrency", ccySettlement)
        Dim calendarNonDeliverable As Variant: Set calendarNonDeliverable = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.HolidayCalendarId", "defaultByCurrency", ccyNonDeliverable)
        Dim calendarIndex As Variant: Set calendarIndex = host.InvokeMethod(calendarSettlement, "combinedWith", calendarNonDeliverable)
        Dim adjustmentFixing As Variant: Set adjustmentFixing = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.DaysAdjustment", "ofBusinessDays", -2, calendar)
        Dim adjustmentMaturity As Variant: Set adjustmentMaturity = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.DaysAdjustment", "ofBusinessDays", 2, calendar)

        Dim indexBuilder As Variant: Set indexBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.index.ImmutableFxIndex", "builder")
        Call host.InvokeMethod(indexBuilder, "currencyPair", ccyPair)
        Call host.InvokeMethod(indexBuilder, "fixingCalendar", calendarIndex)
        Call host.InvokeMethod(indexBuilder, "fixingDateOffset", adjustmentFixing)
        Call host.InvokeMethod(indexBuilder, "maturityDateOffset", adjustmentMaturity)
        Call host.InvokeMethod(indexBuilder, "name", ccyPairName)
        Dim index As Variant: Set index = host.InvokeMethod(indexBuilder, "build")
        
        Dim fxRate As Variant: Set fxRate = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.FxRate", "of", ccySettlement, ccyNonDeliverable, rate)
        Dim settlementAmount As Variant: Set settlementAmount = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.CurrencyAmount", "of", ccySettlement, notional)

        Dim productBuilder As Variant: Set productBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxNdf", "builder")
        Call host.InvokeMethod(productBuilder, "agreedFxRate", fxRate)
        Call host.InvokeMethod(productBuilder, "index", index)
        Call host.InvokeMethod(productBuilder, "paymentDate", maturityDate)
        Call host.InvokeMethod(productBuilder, "settlementCurrencyNotional", settlementAmount)
        Dim product As Variant: Set product = host.InvokeMethod(productBuilder, "build")

        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(i - 1, tradeDate)
        Dim tradeBuilder As Variant: Set tradeBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxNdfTrade", "builder")
        Call host.InvokeMethod(tradeBuilder, "product", product)
        Call host.InvokeMethod(tradeBuilder, "info", tradeInfo)

        Dim trade As Variant: Set trade = host.InvokeMethod(tradeBuilder, "build")
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvValue As Double: pvValue = host.InvokeMethod(pv, "getAmount")
        
        Dim pv01Value As Double
        
        If (pvValue = 0) Then
            pv01Value = 0
        Else
            Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
            Dim pv01Amount As Variant: Set pv01Amount = host.InvokeMethod(pv01, "getAmountOrZero", ccySettlement)
            pv01Value = host.InvokeMethod(pv01Amount, "getAmount")
        End If
        
        ws.Cells(i, cc - 1).Value = pvValue
        ws.Cells(i, cc).Value = pv01Value
        
        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(i - 1)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValue <> 0) Then
        
            Set product = host.InvokeMethod(trade, "getProduct")
            Dim pAgreedFxRate As Variant: Set pAgreedFxRate = host.InvokeMethod(product, "getAgreedFxRate")
            Dim pIndex As Variant: Set pIndex = host.InvokeMethod(product, "getIndex")
            Dim pNotional As Variant: Set pNotional = host.InvokeMethod(product, "getSettlementCurrencyNotional")
            Dim pObservation As Variant: Set pObservation = host.InvokeMethod(product, "getObservation")
            Dim pPaymentDate As Variant: Set pPaymentDate = host.InvokeMethod(product, "getPaymentDate")
            
            Dim cfFxRate As Double: cfFxRate = host.InvokeMethod(pAgreedFxRate, "fxRate", ccySettlement, ccyNonDeliverable)
            Dim cfIndexRate As Variant: Set cfIndexRate = host.InvokeMethod(dd.RatesProvider, "fxIndexRates", pIndex)
            Dim cfObservedRate As Double: cfObservedRate = host.InvokeMethod(cfIndexRate, "rate", pObservation, ccySettlement)
            Dim cfNotional As Variant: Set cfNotional = host.InvokeMethod(pNotional, "multipliedBy", CDbl(1) - (cfFxRate / cfObservedRate))
            
            Dim cfDate As String: cfDate = host.InvokeMethod(pPaymentDate, "format", dd.ReferenceDateFormatter)
            Dim cfAmount As Double: cfAmount = host.InvokeMethod(cfNotional, "getAmount")

            With wsCashFlows.Cells(3, cashFlowsOffset)
                .Value2 = cfDate
                .NumberFormat = "dd/mm/yyyy"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 1)
                .Value2 = ccySettlement
                .NumberFormat = "@"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 2)
                .Value2 = cfAmount
                .NumberFormat = "#,##0.00"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With

        End If
        
        cashFlowsOffset = cashFlowsOffset + 3

    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "FX NON-DELIVERABLE TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingFxSingle()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("FX Single")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count
    
    Dim i As Long, j As Long
    
    If (rc <= 1) Then
        Exit Sub
    Else

        If (((rc - 1) Mod 2) <> 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSingle", "The trades sheet contains an invalid number of rows (" & CStr(rc) & ").")
        End If
    
        For i = 2 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i

    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)
    
    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1

    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.fx.FxSingleTradeCalculations", "DEFAULT")
    Dim id As Long: id = 1

    For i = 2 To rc Step 2

        If (DateDiff("d", refValuationDate, ws.Cells(i, 6).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSingle", "The trade " & CStr(id) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        If (DateDiff("d", ws.Cells(i, 7).Value2, ws.Cells(i, 6).Value2) >= 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSingle", "The trade " & CStr(id) & " must have a maturity date greater than the trade date.")
        End If

        If (ws.Cells(i, 3).Value2 = ws.Cells(i, 5).Value2) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSingle", "The trade " & CStr(id) & " must be defined on different currencies.")
        End If

        Dim iText As String: iText = CStr(i)
        
        Dim direction As Variant: direction = dd.GetDirection("A" & iText, False)
        Dim amountBase As Variant: Set amountBase = dd.GetCurrencyAmount("B" & iText & ":C" & iText)
        Dim amountCounter As Variant: Set amountCounter = dd.GetCurrencyAmount("D" & iText & ":E" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("F" & iText)
        Dim maturityDate As Variant: Set maturityDate = dd.GetDate("G" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("H" & iText)

        If (direction = "BUY") Then
            Set amountBase = host.InvokeMethod(amountBase, "negated")
        Else
            Set amountCounter = host.InvokeMethod(amountCounter, "negated")
        End If
        
        Dim ccyBase As Variant: Set ccyBase = host.InvokeMethod(amountBase, "getCurrency")
        Dim ccyCounter As Variant: Set ccyCounter = host.InvokeMethod(amountCounter, "getCurrency")

        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)
        Set maturityDate = host.InvokeMethod(bda, "adjust", maturityDate, dd.ReferenceData)

        Dim product As Variant: Set product = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSingle", "of", amountBase, amountCounter, maturityDate, bda)

        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(id, tradeDate)
        Dim tradeBuilder As Variant: Set tradeBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSingleTrade", "builder")
        Call host.InvokeMethod(tradeBuilder, "product", product)
        Call host.InvokeMethod(tradeBuilder, "info", tradeInfo)

        Dim trade As Variant: Set trade = host.InvokeMethod(tradeBuilder, "build")
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim ccyPair As Variant: Set ccyPair = host.InvokeMethod(product, "getCurrencyPair")
        Dim ccy1 As Variant: Set ccy1 = host.InvokeMethod(ccyPair, "getBase")
        Dim ccy2 As Variant: Set ccy2 = host.InvokeMethod(ccyPair, "getCounter")
        
        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvAmountBase As Variant: Set pvAmountBase = host.InvokeMethod(pv, "getAmountOrZero", ccy1)
        Dim pvAmountCounter As Variant: Set pvAmountCounter = host.InvokeMethod(pv, "getAmountOrZero", ccy2)
        Dim pvValueBase As Double: pvValueBase = host.InvokeMethod(pvAmountBase, "getAmount")
        Dim pvValueCounter As Double: pvValueCounter = host.InvokeMethod(pvAmountCounter, "getAmount")

        Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
        Dim pv01ValueBase As Double, pv01ValueCounter As Double
        
        If (pvValueBase = 0) Then
            pv01ValueBase = 0
        Else
            Dim pv01AmountBase As Variant: Set pv01AmountBase = host.InvokeMethod(pv01, "getAmountOrZero", ccy1)
            pv01ValueBase = host.InvokeMethod(pv01AmountBase, "getAmount")
        End If
        
        If (pvValueCounter = 0) Then
            pv01ValueCounter = 0
        Else
            Dim pv01AmountCounter As Variant: Set pv01AmountCounter = host.InvokeMethod(pv01, "getAmountOrZero", ccy2)
            pv01ValueCounter = host.InvokeMethod(pv01AmountCounter, "getAmount")
        End If

        If (ccy1 = ccyBase) Then
            ws.Cells(i, cc - 1).Value = pvValueBase
            ws.Cells(i + 1, cc - 1).Value = pvValueCounter
            ws.Cells(i, cc).Value = pv01ValueBase
            ws.Cells(i + 1, cc).Value = pv01ValueCounter
        Else
            ws.Cells(i, cc - 1).Value = pvValueCounter
            ws.Cells(i + 1, cc - 1).Value = pvValueBase
            ws.Cells(i, cc).Value = pv01ValueCounter
            ws.Cells(i + 1, cc).Value = pv01ValueBase
        End If

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(id)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValueBase <> 0) Or (pvValueCounter <> 0) Then
        
            Set product = host.InvokeMethod(trade, "getProduct")
            Dim pPaymentDate As Variant: Set pPaymentDate = host.InvokeMethod(product, "getPaymentDate")
            Dim pPaymentBase As Variant: Set pPaymentBase = host.InvokeMethod(product, "getBaseCurrencyPayment")
            Dim pPaymentCounter As Variant: Set pPaymentCounter = host.InvokeMethod(product, "getCounterCurrencyPayment")

            Dim cfDate As String: cfDate = host.InvokeMethod(pPaymentDate, "format", dd.ReferenceDateFormatter)

            Dim cfValues() As Variant: ReDim cfValues(1, 1)
            cfValues(0, 0) = CStr(ccyBase)
            cfValues(0, 1) = host.InvokeMethod(pPaymentBase, "getAmount")
            cfValues(1, 0) = CStr(ccyCounter)
            cfValues(1, 1) = host.InvokeMethod(pPaymentCounter, "getAmount")

            For j = 0 To 1
            
                With wsCashFlows.Cells(j + 3, cashFlowsOffset)
                    .Value2 = cfDate
                    .NumberFormat = "dd/mm/yyyy"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 1)
                    .Value2 = cfValues(j, 0)
                    .NumberFormat = "@"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 2)
                    .Value2 = cfValues(j, 1)
                    .NumberFormat = "#,##0.00"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
            
            Next j

        End If
        
        id = id + 1
        cashFlowsOffset = cashFlowsOffset + 3

    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "FX SINGLE TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingFxSwap()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("FX Swap")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count
    
    Dim i As Long, j As Long
    
    If (rc <= 2) Then
        Exit Sub
    Else

        If (((rc - 2) Mod 2) <> 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSwap", "The trades sheet contains an invalid number of rows (" & CStr(rc) & ").")
        End If
    
        For i = 3 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i

    End If

    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)

    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1

    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.fx.FxSwapTradeCalculations", "DEFAULT")
    Dim id As Long: id = 1

    For i = 3 To rc Step 2
    
        If (DateDiff("d", refValuationDate, ws.Cells(i, 5).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSwap", "The trade " & CStr(id) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        If (DateDiff("d", ws.Cells(i, 8).Value2, ws.Cells(i, 5).Value2) >= 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSwap", "The trade " & CStr(id) & " must have a near payment date greater than the trade date.")
        End If
        
        If (DateDiff("d", ws.Cells(i, 10).Value2, ws.Cells(i, 8).Value2) >= 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSwap", "The trade " & CStr(id) & " must have a far payment date greater than the near payment date.")
        End If

        If (ws.Cells(i, 3).Value2 = ws.Cells(i, 4).Value2) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFxSwap", "The trade " & CStr(id) & " must be defined on different currencies.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim direction As Variant: direction = dd.GetDirection("A" & iText, False)
        Dim amountBase As Variant: Set amountBase = dd.GetCurrencyAmount("B" & iText & ":C" & iText)
        Dim ccyCounter As Variant: Set ccyCounter = dd.GetCurrency("D" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("E" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("F" & iText)
        Dim amountCounterNear As Double: amountCounterNear = dd.GetAmount("G" & iText)
        Dim paymentDateNear As Variant: Set paymentDateNear = dd.GetDate("H" & iText)
        Dim amountCounterFar As Double: amountCounterFar = dd.GetAmount("I" & iText)
        Dim paymentDateFar As Variant: Set paymentDateFar = dd.GetDate("J" & iText)

        Dim ccyBase As Variant: Set ccyBase = host.InvokeMethod(amountBase, "getCurrency")

        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)
        Set paymentDateNear = host.InvokeMethod(bda, "adjust", paymentDateNear, dd.ReferenceData)
        Set paymentDateFar = host.InvokeMethod(bda, "adjust", paymentDateFar, dd.ReferenceData)

        Dim amountNear As Variant, amountFar As Variant
        Dim legNear As Variant, legFar As Variant

        If (direction = "BUY") Then
            Set amountNear = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.CurrencyAmount", "of", ccyCounter, -amountCounterNear)
            Set amountFar = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.CurrencyAmount", "of", ccyCounter, amountCounterFar)
            Set legNear = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSingle", "of", amountBase, amountNear, paymentDateNear, bda)
            Set legFar = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSingle", "of", host.InvokeMethod(amountBase, "negated"), amountFar, paymentDateFar, bda)
        Else
            Set amountNear = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.CurrencyAmount", "of", ccyCounter, amountCounterNear)
            Set amountFar = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.currency.CurrencyAmount", "of", ccyCounter, -amountCounterFar)
            Set legNear = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSingle", "of", host.InvokeMethod(amountBase, "negated"), amountNear, paymentDateNear, bda)
            Set legFar = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSingle", "of", amountBase, amountFar, paymentDateFar, bda)
        End If

        Dim product As Variant: Set product = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSwap", "of", legNear, legFar)

        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(id, tradeDate)
        Dim tradeBuilder As Variant: Set tradeBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fx.FxSwapTrade", "builder")
        Call host.InvokeMethod(tradeBuilder, "product", product)
        Call host.InvokeMethod(tradeBuilder, "info", tradeInfo)

        Dim trade As Variant: Set trade = host.InvokeMethod(tradeBuilder, "build")
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)
        
        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvAmountBase As Variant: Set pvAmountBase = host.InvokeMethod(pv, "getAmountOrZero", ccyBase)
        Dim pvAmountCounter As Variant: Set pvAmountCounter = host.InvokeMethod(pv, "getAmountOrZero", ccyCounter)
        Dim pvValueBase As Double: pvValueBase = host.InvokeMethod(pvAmountBase, "getAmount")
        Dim pvValueCounter As Double: pvValueCounter = host.InvokeMethod(pvAmountCounter, "getAmount")

        Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
        Dim pv01AmountBase As Variant: Set pv01AmountBase = host.InvokeMethod(pv01, "getAmountOrZero", ccyBase)
        Dim pv01AmountCounter As Variant: Set pv01AmountCounter = host.InvokeMethod(pv01, "getAmountOrZero", ccyCounter)
        Dim pv01ValueBase As Double: pv01ValueBase = host.InvokeMethod(pv01AmountBase, "getAmount")
        Dim pv01ValueCounter As Double: pv01ValueCounter = host.InvokeMethod(pv01AmountCounter, "getAmount")

        If (pvValueBase = 0) Then
            pv01ValueBase = 0
        End If
        
        If (pvValueCounter = 0) Then
            pv01ValueCounter = 0
        End If

        ws.Cells(i, cc - 1).Value = pvValueBase
        ws.Cells(i + 1, cc - 1).Value = pvValueCounter
        ws.Cells(i, cc).Value = pv01ValueBase
        ws.Cells(i + 1, cc).Value = pv01ValueCounter
        
        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(id)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValueBase <> 0) Or (pvValueCounter <> 0) Then
        
            Set product = host.InvokeMethod(trade, "getProduct")

            Dim pLegNear As Variant: Set pLegNear = host.InvokeMethod(product, "getNearLeg")
            Dim pPaymentNearDate As Variant: Set pPaymentNearDate = host.InvokeMethod(pLegNear, "getPaymentDate")
            Dim pPaymentNearBase As Variant: Set pPaymentNearBase = host.InvokeMethod(pLegNear, "getBaseCurrencyPayment")
            Dim pPaymentNearCounter As Variant: Set pPaymentNearCounter = host.InvokeMethod(pLegNear, "getCounterCurrencyPayment")
            
            Dim pLegFar As Variant: Set pLegFar = host.InvokeMethod(product, "getFarLeg")
            Dim pPaymentFarDate As Variant: Set pPaymentFarDate = host.InvokeMethod(pLegFar, "getPaymentDate")
            Dim pPaymentFarBase As Variant: Set pPaymentFarBase = host.InvokeMethod(pLegFar, "getBaseCurrencyPayment")
            Dim pPaymentFarCounter As Variant: Set pPaymentFarCounter = host.InvokeMethod(pLegFar, "getCounterCurrencyPayment")

            Dim cfValues() As Variant: ReDim cfValues(3, 2)
            cfValues(0, 0) = host.InvokeMethod(pPaymentNearDate, "format", dd.ReferenceDateFormatter)
            cfValues(0, 1) = host.InvokeMethod(pPaymentNearBase, "getAmount")
            cfValues(0, 2) = CStr(ccyBase)
            cfValues(1, 0) = host.InvokeMethod(pPaymentNearDate, "format", dd.ReferenceDateFormatter)
            cfValues(1, 1) = host.InvokeMethod(pPaymentNearCounter, "getAmount")
            cfValues(1, 2) = CStr(ccyCounter)
            cfValues(2, 0) = host.InvokeMethod(pPaymentFarDate, "format", dd.ReferenceDateFormatter)
            cfValues(2, 1) = host.InvokeMethod(pPaymentFarBase, "getAmount")
            cfValues(2, 2) = CStr(ccyBase)
            cfValues(3, 0) = host.InvokeMethod(pPaymentFarDate, "format", dd.ReferenceDateFormatter)
            cfValues(3, 1) = host.InvokeMethod(pPaymentFarCounter, "getAmount")
            cfValues(3, 2) = CStr(ccyCounter)
            
            For j = 0 To 3
            
                With wsCashFlows.Cells(j + 3, cashFlowsOffset)
                    .Value2 = cfValues(j, 0)
                    .NumberFormat = "dd/mm/yyyy"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 1)
                    .Value2 = cfValues(j, 2)
                    .NumberFormat = "@"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 2)
                    .Value2 = cfValues(j, 1)
                    .NumberFormat = "#,##0.00"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
            
            Next j

        End If
        
        id = id + 1
        cashFlowsOffset = cashFlowsOffset + 3
    
    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "FX SWAP TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingBulletPayment()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("Bullet Payment")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count
    
    Dim i As Long, j As Long
    
    If (rc <= 1) Then
        Exit Sub
    Else
        For i = 2 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i
    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)
    
    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1
    
    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.payment.BulletPaymentTradeCalculations", "DEFAULT")

    For i = 2 To rc
    
        If (DateDiff("d", refValuationDate, ws.Cells(i, 4).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingBulletPayment", "The trade " & CStr(i - 1) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        If (DateDiff("d", ws.Cells(i, 5).Value2, ws.Cells(i, 4).Value2) >= 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingBulletPayment", "The trade " & CStr(i - 1) & " must have a maturity date greater than the trade date.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim direction As Variant: Set direction = dd.GetPaymentDirection("A" & iText, True)
        Dim amount As Variant: Set amount = dd.GetCurrencyAmount("B" & iText & ":C" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("D" & iText)
        Dim maturityDate As Variant: Set maturityDate = dd.GetDate("E" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("F" & iText)
        
        Dim ccy As Variant: Set ccy = host.InvokeMethod(amount, "getCurrency")
 
        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)
        Set maturityDate = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.AdjustableDate", "of", maturityDate, bda)
 
        Dim productBuilder As Variant: Set productBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.payment.BulletPayment", "builder")
        Call host.InvokeMethod(productBuilder, "date", maturityDate)
        Call host.InvokeMethod(productBuilder, "payReceive", direction)
        Call host.InvokeMethod(productBuilder, "value", amount)
        Dim product As Variant: Set product = host.InvokeMethod(productBuilder, "build")
        
        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(i - 1, tradeDate)
        Dim tradeBuilder As Variant: Set tradeBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.payment.BulletPaymentTrade", "builder")
        Call host.InvokeMethod(tradeBuilder, "product", product)
        Call host.InvokeMethod(tradeBuilder, "info", tradeInfo)

        Dim trade As Variant: Set trade = host.InvokeMethod(tradeBuilder, "build")
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvValue As Double: pvValue = host.InvokeMethod(pv, "getAmount")

        Dim pv01Value As Double
        
        If (pvValue = 0) Then
            pv01Value = 0
        Else
            Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
            Dim pv01Amount As Variant: Set pv01Amount = host.InvokeMethod(pv01, "getAmountOrZero", ccy)
            pv01Value = host.InvokeMethod(pv01Amount, "getAmount")
        End If

        ws.Cells(i, cc - 1).Value = pvValue
        ws.Cells(i, cc).Value = pv01Value

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(i - 1)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValue <> 0) Then
        
            Set product = host.InvokeMethod(trade, "getProduct")
            Dim pPayment As Variant: Set pPayment = host.InvokeMethod(product, "getPayment")
            Dim pPaymentAmount As Variant: Set pPaymentAmount = host.InvokeMethod(pPayment, "getValue")
            Dim pPaymentDate As Variant: Set pPaymentDate = host.InvokeMethod(pPayment, "getDate")

            With wsCashFlows.Cells(3, cashFlowsOffset)
                .Value2 = host.InvokeMethod(pPaymentDate, "format", dd.ReferenceDateFormatter)
                .NumberFormat = "dd/mm/yyyy"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 1)
                .Value2 = CStr(ccy)
                .NumberFormat = "@"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 2)
                .Value2 = host.InvokeMethod(pPaymentAmount, "getAmount")
                .NumberFormat = "#,##0.00"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With

        End If
        
        cashFlowsOffset = cashFlowsOffset + 3
    
    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "BULLET PAYMENT TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingTermDeposit()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("Term Deposit")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count
    
    Dim i As Long, j As Long
    
    If (rc <= 1) Then
        Exit Sub
    Else
        For i = 2 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i
    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)
    
    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1
    
    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.deposit.TermDepositTradeCalculations", "DEFAULT")

    For i = 2 To rc
    
        If (DateDiff("d", refValuationDate, ws.Cells(i, 5).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingTermDeposit", "The trade " & CStr(i - 1) & " must have a trade date less than or equal to the valuation date.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim direction As Variant: Set direction = dd.GetDirection("A" & iText, True)
        Dim notional As Double: notional = dd.GetAmount("B" & iText)
        Dim ccy As Variant: Set ccy = dd.GetCurrency("C" & iText)
        Dim rate As Double: rate = dd.GetRate("D" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("E" & iText)
        Dim period As Variant: Set period = dd.GetPeriod("F" & iText)
        Dim dcc As Variant: Set dcc = dd.GetDaysCountConvention("G" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("H" & iText)
 
        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Dim da As Variant: Set da = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.DaysAdjustment", "ofBusinessDays", 2, calendar, bda)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)
 
        Dim conventionBuilder As Variant: Set conventionBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.deposit.type.ImmutableTermDepositConvention", "builder")
        Call host.InvokeMethod(conventionBuilder, "businessDayAdjustment", bda)
        Call host.InvokeMethod(conventionBuilder, "currency", ccy)
        Call host.InvokeMethod(conventionBuilder, "dayCount", dcc)
        Call host.InvokeMethod(conventionBuilder, "name", "CONVENTION-TERMDEPOSIT-" & CStr(i - 1))
        Call host.InvokeMethod(conventionBuilder, "spotDateOffset", da)
        Dim convention As Variant: Set convention = host.InvokeMethod(conventionBuilder, "build")
        
        Dim templateBuilder As Variant: Set templateBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.deposit.type.TermDepositTemplate", "builder")
        Call host.InvokeMethod(templateBuilder, "convention", convention)
        Call host.InvokeMethod(templateBuilder, "depositPeriod", period)
        Dim template As Variant: Set template = host.InvokeMethod(templateBuilder, "build")

        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(i - 1, tradeDate)
        Dim trade As Variant: Set trade = host.InvokeMethod(template, "createTrade", tradeDate, direction, notional, rate, dd.ReferenceData)
        Set trade = host.InvokeMethod(trade, "withInfo", tradeInfo)
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvValue As Double: pvValue = host.InvokeMethod(pv, "getAmount")

        Dim pv01Value As Double
        
        If (pvValue = 0) Then
            pv01Value = 0
        Else
            Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
            Dim pv01Amount As Variant: Set pv01Amount = host.InvokeMethod(pv01, "getAmountOrZero", ccy)
            pv01Value = host.InvokeMethod(pv01Amount, "getAmount")
        End If

        ws.Cells(i, cc - 1).Value = pvValue
        ws.Cells(i, cc).Value = pv01Value

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(i - 1)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValue <> 0) Then
        
            Dim product As Variant: Set product = host.InvokeMethod(trade, "getProduct")
            Dim pStartDate As Variant: Set pStartDate = host.InvokeMethod(product, "getStartDate")
            Dim pEndDate As Variant: Set pEndDate = host.InvokeMethod(product, "getEndDate")

            Dim cfAmountStart As Double: cfAmountStart = -host.InvokeMethod(product, "getNotional")
            Dim cfAmountEnd As Double: cfAmountEnd = host.InvokeMethod(product, "getNotional") + host.InvokeMethod(product, "getInterest")

            Dim cfValues() As Variant: ReDim cfValues(1, 2)
            cfValues(0, 0) = host.InvokeMethod(pStartDate, "format", dd.ReferenceDateFormatter)
            cfValues(0, 1) = CStr(ccy)
            cfValues(0, 2) = cfAmountStart
            cfValues(1, 0) = host.InvokeMethod(pEndDate, "format", dd.ReferenceDateFormatter)
            cfValues(1, 1) = CStr(ccy)
            cfValues(1, 2) = cfAmountEnd

            For j = 0 To 1
            
                With wsCashFlows.Cells(j + 3, cashFlowsOffset)
                    .Value2 = cfValues(j, 0)
                    .NumberFormat = "dd/mm/yyyy"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 1)
                    .Value2 = cfValues(j, 1)
                    .NumberFormat = "@"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 2)
                    .Value2 = cfValues(j, 2)
                    .NumberFormat = "#,##0.00"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
            
            Next j

        End If
        
        cashFlowsOffset = cashFlowsOffset + 3

    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "TERM DEPOSIT TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingCrossCurrencySwap()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("Cross-Currency Swap")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count

    Dim i As Long, j As Long
    
    If (rc <= 2) Then
        Exit Sub
    Else

        If (((rc - 2) Mod 2) <> 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trades sheet contains an invalid number of rows (" & CStr(rc) & ").")
        End If
    
        For i = 3 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i

    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)

    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1

    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.swap.SwapTradeCalculations", "DEFAULT")
    Dim id As Long: id = 1

    For i = 3 To rc Step 2

        If (DateDiff("d", refValuationDate, ws.Cells(i, 1).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        Dim legTypePay As Variant: legTypePay = ws.Cells(i, 5).Value2
        
        If IsEmpty(legTypePay) Or (VarType(legTypePay) <> vbString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " is defined on an invalid pay leg type.")
        End If
        
        legTypePay = UCase$(Trim$(legTypePay))
    
        If (legTypePay = vbNullString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " is defined on an invalid pay leg type.")
        End If

        Dim legTypeReceive As Variant: legTypeReceive = ws.Cells(i, 9).Value2
        
        If IsEmpty(legTypeReceive) Or (VarType(legTypeReceive) <> vbString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " is defined on an invalid receive leg type.")
        End If
        
        legTypeReceive = UCase$(Trim$(legTypeReceive))
    
        If (legTypeReceive = vbNullString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " is defined on an invalid receive leg type.")
        End If
        
        Dim tradeType As String: tradeType = legTypePay & "/" & legTypeReceive
        
        If (tradeType <> "FLAT/SPREAD") And (tradeType <> "SPREAD/FLAT") Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " is defined on an invalid convention.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("A" & iText)
        Dim startPeriod As Variant: Set startPeriod = dd.GetPeriod("B" & iText)
        Dim tenor As Variant: Set tenor = dd.GetTenor("C" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("D" & iText)

        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Dim da As Variant: Set da = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.DaysAdjustment", "ofBusinessDays", 2, calendar, bda)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)

        Dim direction As Variant
        Dim indexFlat As Variant
        Dim indexSpread As Variant
        Dim notionalFlat As Double
        Dim notionalSpread As Double
        Dim spread As Double
    
        If (tradeType = "FLAT/SPREAD") Then
            Set direction = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "SELL")
            notionalFlat = dd.GetAmount("F" & iText)
            Set indexFlat = dd.GetIborIndex("G" & iText)
            notionalSpread = dd.GetAmount("J" & iText)
            Set indexSpread = dd.GetIborIndex("K" & iText)
            spread = dd.GetRate("L" & iText)
        Else
            Set direction = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "BUY")
            notionalFlat = dd.GetAmount("J" & iText)
            Set indexFlat = dd.GetIborIndex("K" & iText)
            notionalSpread = dd.GetAmount("F" & iText)
            Set indexSpread = dd.GetIborIndex("G" & iText)
            spread = dd.GetRate("H" & iText)
        End If
        
        Dim ccyFlat As Variant: Set ccyFlat = host.InvokeMethod(indexFlat, "getCurrency")
        Dim ccySpread As Variant: Set ccySpread = host.InvokeMethod(indexSpread, "getCurrency")
        
        If (ccyFlat = ccySpread) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " must have the two legs defined on different currencies.")
        End If
        
        Dim tenorFlat As Variant: Set tenorFlat = host.InvokeMethod(indexFlat, "getTenor")
        Dim tenorSpread As Variant: Set tenorSpread = host.InvokeMethod(indexSpread, "getTenor")
        Dim tenorComparison As Long: tenorComparison = host.InvokeMethod(tenorFlat, "compareTo", tenorSpread)
        
        If (tenorComparison <> 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingCrossCurrencySwap", "The trade " & CStr(id) & " must have the same tenor on both legs.")
        End If
        
        Dim conventionBuilderFlat As Variant: Set conventionBuilderFlat = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborRateSwapLegConvention", "builder")
        Call host.InvokeMethod(conventionBuilderFlat, "accrualBusinessDayAdjustment", bda)
        Call host.InvokeMethod(conventionBuilderFlat, "index", indexFlat)
        Call host.InvokeMethod(conventionBuilderFlat, "notionalExchange", True)
        Call host.InvokeMethod(conventionBuilderFlat, "paymentDateOffset", da)
        Dim conventionFlat As Variant: Set conventionFlat = host.InvokeMethod(conventionBuilderFlat, "build")

        Dim conventionBuilderSpread As Variant: Set conventionBuilderSpread = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborRateSwapLegConvention", "builder")
        Call host.InvokeMethod(conventionBuilderSpread, "accrualBusinessDayAdjustment", bda)
        Call host.InvokeMethod(conventionBuilderSpread, "index", indexSpread)
        Call host.InvokeMethod(conventionBuilderSpread, "notionalExchange", True)
        Call host.InvokeMethod(conventionBuilderSpread, "paymentDateOffset", da)
        Dim conventionSpread As Variant: Set conventionSpread = host.InvokeMethod(conventionBuilderSpread, "build")
        
        Dim conventionBuilder As Variant: Set conventionBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.ImmutableXCcyIborIborSwapConvention", "builder")
        Call host.InvokeMethod(conventionBuilder, "flatLeg", conventionFlat)
        Call host.InvokeMethod(conventionBuilder, "spreadLeg", conventionSpread)
        Call host.InvokeMethod(conventionBuilder, "name", "CONVENTION-CROSSCURRENCYSWAP-" & CStr(id))
        Call host.InvokeMethod(conventionBuilder, "spotDateOffset", da)
        Dim convention As Variant: Set convention = host.InvokeMethod(conventionBuilder, "build")

        Dim template As Variant: Set template = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.XCcyIborIborSwapTemplate", "of", startPeriod, tenor, convention)
        Dim trade As Variant: Set trade = host.InvokeMethod(template, "createTrade", tradeDate, direction, notionalSpread, notionalFlat, spread, dd.ReferenceData)

        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(id, tradeDate)
        Set trade = host.InvokeMethod(trade, "withInfo", tradeInfo)
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvAmountFlat As Variant: Set pvAmountFlat = host.InvokeMethod(pv, "getAmountOrZero", ccyFlat)
        Dim pvValueFlat As Double: pvValueFlat = host.InvokeMethod(pvAmountFlat, "getAmount")
        Dim pvAmountSpread As Variant: Set pvAmountSpread = host.InvokeMethod(pv, "getAmountOrZero", ccySpread)
        Dim pvValueSpread As Double: pvValueSpread = host.InvokeMethod(pvAmountSpread, "getAmount")
        
        Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
        Dim pv01ValueFlat As Double, pv01ValueSpread As Double
        
        If (pvValueFlat = 0) Then
            pv01ValueFlat = 0
        Else
            Dim pv01AmountFlat As Variant: Set pv01AmountFlat = host.InvokeMethod(pv01, "getAmountOrZero", ccyFlat)
            pv01ValueFlat = host.InvokeMethod(pv01AmountFlat, "getAmount")
        End If
        
        If (pvValueSpread = 0) Then
            pv01ValueSpread = 0
        Else
            Dim pv01AmountSpread As Variant: Set pv01AmountSpread = host.InvokeMethod(pv01, "getAmountOrZero", ccySpread)
            pv01ValueSpread = host.InvokeMethod(pv01AmountSpread, "getAmount")
        End If
        
        If (tradeType = "FLAT/SPREAD") Then
            ws.Cells(i, cc - 1).Value = pvValueFlat
            ws.Cells(i + 1, cc - 1).Value = pvValueSpread
            ws.Cells(i, cc).Value = pv01ValueFlat
            ws.Cells(i + 1, cc).Value = pv01ValueSpread
        Else
            ws.Cells(i, cc - 1).Value = pvValueSpread
            ws.Cells(i + 1, cc - 1).Value = pvValueFlat
            ws.Cells(i, cc).Value = pv01ValueSpread
            ws.Cells(i + 1, cc).Value = pv01ValueFlat
        End If

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(id)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValueFlat <> 0) Or (pv01ValueSpread <> 0) Then
        
            Dim cashFlows As Variant: Set cashFlows = host.InvokeMethod(pricer, "cashFlows", trade, dd.RatesProvider)
            Dim cashFlowsSorted As Variant: Set cashFlowsSorted = host.InvokeMethod(cashFlows, "sorted")
            Dim cashFlowsSortedList As Variant: Set cashFlowsSortedList = host.InvokeMethod(cashFlowsSorted, "getCashFlows")
            Dim cashFlowsSortedListCount As Long: cashFlowsSortedListCount = host.InvokeMethod(cashFlowsSortedList, "size")
            
            For j = 0 To cashFlowsSortedListCount - 1
            
                Dim cashFlow As Variant: Set cashFlow = host.InvokeMethod(cashFlowsSortedList, "get", j)
                Dim cashFlowAmount As Variant: Set cashFlowAmount = host.InvokeMethod(cashFlow, "getPresentValue")
                Dim cashFlowPaymentDate As Variant: Set cashFlowPaymentDate = host.InvokeMethod(cashFlow, "getPaymentDate")

                With wsCashFlows.Cells(j + 3, cashFlowsOffset)
                    .Value2 = host.InvokeMethod(cashFlowPaymentDate, "format", dd.ReferenceDateFormatter)
                    .NumberFormat = "dd/mm/yyyy"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 1)
                    .Value2 = CStr(host.InvokeMethod(cashFlowAmount, "getCurrency"))
                    .NumberFormat = "@"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 2)
                    .Value2 = host.InvokeMethod(cashFlowAmount, "getAmount")
                    .NumberFormat = "#,##0.00"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
            
            Next j

        End If
        
        id = id + 1
        cashFlowsOffset = cashFlowsOffset + 3

    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "CROSS-CURRENCY SWAP TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingFra()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("FRA")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count

    Dim i As Long, j As Long
    
    If (rc <= 1) Then
        Exit Sub
    Else
        For i = 2 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i
    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)

    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1

    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.fra.FraTradeCalculations", "DEFAULT")

    For i = 2 To rc

        If (DateDiff("d", refValuationDate, ws.Cells(i, 5).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingFra", "The trade " & CStr(i - 1) & " must have a trade date less than or equal to the valuation date.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim direction As Variant: Set direction = dd.GetDirection("A" & iText, True)
        Dim notional As Double: notional = dd.GetAmount("B" & iText)
        Dim index As Variant: Set index = dd.GetIborIndex("C" & iText)
        Dim rate As Double: rate = dd.GetRate("D" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("E" & iText)
        Dim startPeriod As Variant: Set startPeriod = dd.GetPeriod("F" & iText, "M")
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("G" & iText)
        
        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)

        Dim template As Variant: Set template = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fra.type.FraTemplate", "of", startPeriod, index)
        Dim trade As Variant: Set trade = host.InvokeMethod(template, "createTrade", tradeDate, direction, notional, rate, dd.ReferenceData)
        Dim product As Variant: Set product = host.InvokeMethod(trade, "getProduct")
        
        Dim productBuilder As Variant: Set productBuilder = host.InvokeMethod(product, "toBuilder")
        Call host.InvokeMethod(productBuilder, "businessDayAdjustment", bda)
        Set product = host.InvokeMethod(productBuilder, "build")
        
        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(i - 1, tradeDate)
        Dim tradeBuilder As Variant: Set tradeBuilder = host.InvokeMethodStaticFromName("com.opengamma.strata.product.fra.FraTrade", "builder")
        Call host.InvokeMethod(tradeBuilder, "product", product)
        Call host.InvokeMethod(tradeBuilder, "info", tradeInfo)
        
        Set trade = host.InvokeMethod(tradeBuilder, "build")
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim ccy As Variant: Set ccy = host.InvokeMethod(product, "getCurrency")

        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvValue As Double: pvValue = host.InvokeMethod(pv, "getAmount")

        Dim pv01Value As Double

        If (pvValue = 0) Then
            pv01Value = 0
        Else
            Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
            Dim pv01Amount As Variant: Set pv01Amount = host.InvokeMethod(pv01, "getAmountOrZero", ccy)
            pv01Value = host.InvokeMethod(pv01Amount, "getAmount")
        End If

        ws.Cells(i, cc - 1).Value = pvValue
        ws.Cells(i, cc).Value = pv01Value

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(i - 1)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValue <> 0) Then
        
            Set product = host.InvokeMethod(trade, "getProduct")
            Dim pPaymentDate As Variant: Set pPaymentDate = host.InvokeMethod(product, "getPaymentDate")

            With wsCashFlows.Cells(3, cashFlowsOffset)
                .Value2 = host.InvokeMethod(pPaymentDate, "format", dd.ReferenceDateFormatter)
                .NumberFormat = "dd/mm/yyyy"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 1)
                .Value2 = CStr(ccy)
                .NumberFormat = "@"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 2)
                .Value2 = pvValue
                .NumberFormat = "#,##0.00"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With

        End If
        
        cashFlowsOffset = cashFlowsOffset + 3
    
    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "FRA TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingInterestRateFuture()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("Interest Rate Future")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count

    Dim i As Long, j As Long
    
    If (rc <= 1) Then
        Exit Sub
    Else
        For i = 2 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i
    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)
    
    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1
    
    Dim valuationDate As Variant: Set valuationDate = host.InvokeMethod(dd.RatesProvider, "getValuationDate")

    For i = 2 To rc

        If (DateDiff("d", refValuationDate, ws.Cells(i, 8).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateFuture", "The trade " & CStr(i - 1) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        Dim tradeType As Variant: tradeType = ws.Cells(i, 1).Value2
        
        If IsEmpty(tradeType) Or (VarType(tradeType) <> vbString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateFuture", "The trade " & CStr(i - 1) & " is defined on an invalid type.")
        End If
        
        tradeType = UCase$(Trim$(tradeType))
    
        If (tradeType = vbNullString) Or ((tradeType <> "IBOR") And (tradeType <> "OVERNIGHT")) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 1) & " is defined on an invalid type.")
        End If

        Dim iText As String: iText = CStr(i)

        Dim direction As Variant: direction = dd.GetDirection("B" & iText, False)
        Dim notional As Double: notional = dd.GetAmount("C" & iText)
        Dim quantity As Double: quantity = dd.GetQuantity("G" & iText)
        Dim price As Double: price = dd.GetPrice("H" & iText)
        Dim lastPrice As Double: lastPrice = dd.GetPrice("I" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("J" & iText)
        Dim maturity As Variant: Set maturity = dd.GetFutureMaturity("K" & iText)
        Dim dateSequence As Variant: Set dateSequence = dd.GetDateSequence("L" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("M" & iText)

        If (direction = "SELL") Then
            quantity = -quantity
        End If
        
        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)

        Dim ccy As Variant
        Dim pricer As Variant
        Dim trade As Variant

        If (tradeType = "IBOR") Then

            Dim indexI As Variant: Set indexI = dd.GetIborIndex("D" & iText)

            Dim securityNameI As Variant: securityNameI = host.InvokeMethod(indexI, "getName")
            Dim securityIdI As Variant: Set securityIdI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.SecurityId", "of", "Future", securityNameI)

            Dim conventionBuilderI As Variant: Set conventionBuilderI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.index.type.ImmutableIborFutureConvention", "builder")
            Call host.InvokeMethod(conventionBuilderI, "businessDayAdjustment", bda)
            Call host.InvokeMethod(conventionBuilderI, "dateSequence", dateSequence)
            Call host.InvokeMethod(conventionBuilderI, "index", indexI)
            Call host.InvokeMethod(conventionBuilderI, "name", "CONVENTION-INTERESTRATEFUTURE-" & CStr(i - 1))
            Dim conventionI As Variant: Set conventionI = host.InvokeMethod(conventionBuilderI, "build")
            
            Dim templateI As Variant: Set templateI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.index.type.IborFutureTemplate", "of", maturity, conventionI)

            Set ccy = host.InvokeMethod(indexI, "getCurrency")
            Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.pricer.index.DiscountingIborFutureTradePricer", "DEFAULT")
            Set trade = host.InvokeMethod(templateI, "createTrade", tradeDate, securityIdI, quantity, notional, price, dd.ReferenceData)
        
        Else
        
            Dim indexO As Variant: Set indexO = dd.GetOvernightIndex("D" & iText)
            Dim frequencyO As Variant: Set frequencyO = dd.GetFrequency("E" & iText)
            Dim accrualO As Variant: Set accrualO = dd.GetOvernightAccrualMethod("F" & iText)
            
            Dim accrualPeriodO As Variant: Set accrualPeriodO = host.InvokeMethod(frequencyO, "getPeriod")
            Dim accrualMonthsO As Variant: accrualMonthsO = host.InvokeMethod(accrualPeriodO, "toTotalMonths")
            Dim accrualFactorO As Double: accrualFactorO = CDbl(accrualMonthsO) / CDbl(1)

            Dim endDateO As Variant: Set endDateO = host.InvokeMethod(dateSequence, "dateMatching", maturity)
            Set endDateO = host.InvokeMethod(bda, "adjust", endDateO, dd.ReferenceData)
            
            Dim daO As Variant: Set daO = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.DaysAdjustment", "ofBusinessDays", -2, calendar, bda)
            Dim lastTradeDateO As Variant: Set lastTradeDateO = endDateO
            Set lastTradeDateO = host.InvokeMethod(daO, "adjust", lastTradeDateO, dd.ReferenceData)

            Dim securityNameO As Variant: securityNameO = host.InvokeMethod(indexO, "getName")
            Dim securityIdO As Variant: Set securityIdO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.SecurityId", "of", "Future", securityNameO)

            Dim productBuilderO As Variant: Set productBuilderO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.index.OvernightFuture", "builder")
            Call host.InvokeMethod(productBuilderO, "accrualFactor", accrualFactorO)
            Call host.InvokeMethod(productBuilderO, "accrualMethod", accrualO)
            Call host.InvokeMethod(productBuilderO, "endDate", endDateO)
            Call host.InvokeMethod(productBuilderO, "index", indexO)
            Call host.InvokeMethod(productBuilderO, "lastTradeDate", lastTradeDateO)
            Call host.InvokeMethod(productBuilderO, "notional", notional)
            Call host.InvokeMethod(productBuilderO, "securityId", securityIdO)
            Call host.InvokeMethod(productBuilderO, "startDate", tradeDate)
            Dim productO As Variant: Set productO = host.InvokeMethod(productBuilderO, "build")
            
            Dim tradeBuilderO As Variant: Set tradeBuilderO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.index.OvernightFutureTrade", "builder")
            Call host.InvokeMethod(tradeBuilderO, "product", productO)
            Call host.InvokeMethod(tradeBuilderO, "price", price)
            Call host.InvokeMethod(tradeBuilderO, "quantity", quantity)

            Set ccy = host.InvokeMethod(indexO, "getCurrency")
            Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.pricer.index.DiscountingOvernightFutureTradePricer", "DEFAULT")
            Set trade = host.InvokeMethod(tradeBuilderO, "build")
        
        End If
        
        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(i - 1, tradeDate)
        Set trade = host.InvokeMethod(trade, "withInfo", tradeInfo)
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)
        
        Dim product As Variant: Set product = host.InvokeMethod(trade, "getProduct")
        
        Dim endDate As Variant
        
        If (tradeType = "IBOR") Then
            Dim rateI As Variant: Set rateI = host.InvokeMethod(product, "getIborRate")
            Set endDate = host.InvokeMethod(rateI, "getMaturityDate")
        Else
            Dim rateO As Variant: Set rateO = host.InvokeMethod(product, "getOvernightRate")
            Set endDate = host.InvokeMethod(rateO, "getEndDate")
        End If
        
        Dim reachedMaturity As Variant: reachedMaturity = host.InvokeMethod(endDate, "isBefore", valuationDate)
        
        Dim pvValue As Double, pv01Value As Double

        If reachedMaturity Then
            pvValue = 0
            pv01Value = 0
        Else
        
            Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider, lastPrice)
            pvValue = host.InvokeMethod(pv, "getAmount")

            Dim pvs As Variant: Set pvs = host.InvokeMethod(pricer, "presentValueSensitivity", trade, dd.RatesProvider)
            Dim pvsParam As Variant: Set pvsParam = host.InvokeMethod(dd.RatesProvider, "parameterSensitivity", pvs)
            Dim pvsParamTotal As Variant: Set pvsParamTotal = host.InvokeMethod(pvsParam, "total")
            Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pvsParamTotal, "multipliedBy", 0.0001)
            Dim pv01Amount As Variant: Set pv01Amount = host.InvokeMethod(pv01, "getAmountOrZero", ccy)
            pv01Value = host.InvokeMethod(pv01Amount, "getAmount")

        End If
        
        ws.Cells(i, cc - 1).Value = pvValue
        ws.Cells(i, cc).Value = pv01Value

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(i - 1)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If Not reachedMaturity Then

            With wsCashFlows.Cells(3, cashFlowsOffset)
                .Value2 = host.InvokeMethod(endDate, "format", dd.ReferenceDateFormatter)
                .NumberFormat = "dd/mm/yyyy"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 1)
                .Value2 = CStr(ccy)
                .NumberFormat = "@"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With
            
            With wsCashFlows.Cells(3, cashFlowsOffset + 2)
                .Value2 = pvValue
                .NumberFormat = "#,##0.00"
                .Borders.Color = 0
                .Borders.LineStyle = xlContinuous
                .Borders.Weight = xlThin
                .Interior.Color = 16777215
            End With

        End If
        
        cashFlowsOffset = cashFlowsOffset + 3

    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "INTEREST RATE FUTURE TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

Public Sub PricingInterestRateSwap()

    Dim form As New ReferenceData: form.Show
    Dim refValuationDate As Date: refValuationDate = form.ReferenceValuationDate
    Dim refBDC As String: refBDC = form.ReferenceBusinessDays
    Dim refCcy As String: refCcy = form.ReferenceCurrency
    Call Unload(form)
    
    On Error GoTo ErrorHandler
    
    Application.EnableEvents = False
    Application.ScreenUpdating = False

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets("Interest Rate Swap")
    Dim cc As Long: cc = ws.UsedRange.Columns.Count
    Dim rc As Long: rc = ws.UsedRange.Rows.Count

    Dim i As Long, j As Long
    
    If (rc <= 2) Then
        Exit Sub
    Else
        For i = 3 To rc
            For j = cc - 1 To cc
                ws.Cells(i, j).ClearContents
            Next j
        Next i
    End If
    
    Dim host As New RuntimeHost: Call host.Initialize
    Dim dd As New DataDispatcher: Call dd.Initialize(host, refValuationDate, refBDC, refCcy, ws)

    Dim wsCashFlows As Worksheet: Set wsCashFlows = PrepareCashFlows(ws)
    Dim cashFlowsOffset As Long: cashFlowsOffset = 1

    Dim pricer As Variant: Set pricer = host.GetPropertyStaticFromName("com.opengamma.strata.measure.swap.SwapTradeCalculations", "DEFAULT")
    Dim valuationDate As Variant: Set valuationDate = host.InvokeMethod(dd.RatesProvider, "getValuationDate")

    For i = 3 To rc

        If (DateDiff("d", refValuationDate, ws.Cells(i, 2).Value2) > 0) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " must have a trade date less than or equal to the valuation date.")
        End If
        
        Dim legTypePay As Variant: legTypePay = ws.Cells(i, 6).Value2
        
        If IsEmpty(legTypePay) Or (VarType(legTypePay) <> vbString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " is defined on an invalid pay leg type.")
        End If
        
        legTypePay = UCase$(Trim$(legTypePay))
    
        If (legTypePay = vbNullString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " is defined on an invalid pay leg type.")
        End If

        Dim legTypeReceive As Variant: legTypeReceive = ws.Cells(i, 11).Value2
        
        If IsEmpty(legTypeReceive) Or (VarType(legTypeReceive) <> vbString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " is defined on an invalid receive leg type.")
        End If
        
        legTypeReceive = UCase$(Trim$(legTypeReceive))
    
        If (legTypeReceive = vbNullString) Then
            Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " is defined on an invalid receive leg type.")
        End If
        
        Dim tradeType As String: tradeType = legTypePay & " / " & legTypeReceive

        Dim iText As String: iText = CStr(i)

        Dim notional As Double: notional = dd.GetAmount("A" & iText)
        Dim tradeDate As Variant: Set tradeDate = dd.GetDate("B" & iText)
        Dim startPeriod As Variant: Set startPeriod = dd.GetPeriod("C" & iText)
        Dim tenor As Variant: Set tenor = dd.GetTenor("D" & iText)
        Dim calendarCpty As Variant: Set calendarCpty = dd.GetCalendar("E" & iText)

        Dim calendar As Variant: Set calendar = host.InvokeMethod(dd.ReferenceCalendar, "combinedWith", calendarCpty)
        Dim bda As Variant: Set bda = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.BusinessDayAdjustment", "of", dd.ReferenceBusinessDays, calendar)
        Dim da As Variant: Set da = host.InvokeMethodStaticFromName("com.opengamma.strata.basics.date.DaysAdjustment", "ofBusinessDays", 2, calendar, bda)
        Set tradeDate = host.InvokeMethod(bda, "adjust", tradeDate, dd.ReferenceData)

        Dim ccy As Variant
        Dim trade As Variant

        Select Case tradeType
        
            Case "FIXED / IBOR", "IBOR / FIXED"
            
                Dim directionFI As Variant
                Dim ccyFixedFI As Variant
                Dim frequencyFixedFI As Variant
                Dim dccFixedFI As Variant
                Dim rateFI As Double
                Dim indexFloatingFI As Variant

                If (tradeType = "FIXED / IBOR") Then
                    Set directionFI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "BUY")
                    Set ccyFixedFI = dd.GetCurrency("G" & iText)
                    Set frequencyFixedFI = dd.GetFrequency("H" & iText)
                    Set dccFixedFI = dd.GetDaysCountConvention("I" & iText)
                    Set indexFloatingFI = dd.GetIborIndex("L" & iText)
                    rateFI = dd.GetRate("J" & iText)
                Else
                    Set directionFI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "SELL")
                    Set ccyFixedFI = dd.GetCurrency("L" & iText)
                    Set frequencyFixedFI = dd.GetFrequency("M" & iText)
                    Set dccFixedFI = dd.GetDaysCountConvention("N" & iText)
                    Set indexFloatingFI = dd.GetIborIndex("G" & iText)
                    rateFI = dd.GetRate("O" & iText)
                End If
                
                Dim ccyFloatingFI As Variant: Set ccyFloatingFI = host.InvokeMethod(indexFloatingFI, "getCurrency")
                
                If (ccyFixedFI <> ccyFloatingFI) Then
                    Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " must have the two legs defined on the same currency.")
                End If
                
                Set ccy = ccyFixedFI

                Dim conventionBuilderFixedFI As Variant: Set conventionBuilderFixedFI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.FixedRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFixedFI, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderFixedFI, "accrualFrequency", frequencyFixedFI)
                Call host.InvokeMethod(conventionBuilderFixedFI, "currency", ccyFixedFI)
                Call host.InvokeMethod(conventionBuilderFixedFI, "dayCount", dccFixedFI)
                Call host.InvokeMethod(conventionBuilderFixedFI, "paymentDateOffset", da)
                Dim conventionFixedFI As Variant: Set conventionFixedFI = host.InvokeMethod(conventionBuilderFixedFI, "build")
                
                Dim conventionBuilderFloatingFI As Variant: Set conventionBuilderFloatingFI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFloatingFI, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderFloatingFI, "index", indexFloatingFI)
                Call host.InvokeMethod(conventionBuilderFloatingFI, "notionalExchange", False)
                Call host.InvokeMethod(conventionBuilderFloatingFI, "paymentDateOffset", da)
                Dim conventionFloatingFI As Variant: Set conventionFloatingFI = host.InvokeMethod(conventionBuilderFloatingFI, "build")

                Dim conventionBuilderFI As Variant: Set conventionBuilderFI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.ImmutableFixedIborSwapConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFI, "fixedLeg", conventionFixedFI)
                Call host.InvokeMethod(conventionBuilderFI, "floatingLeg", conventionFloatingFI)
                Call host.InvokeMethod(conventionBuilderFI, "name", "CONVENTION-INTERESTRATESWAP-" & CStr(i - 2))
                Call host.InvokeMethod(conventionBuilderFI, "spotDateOffset", da)
                Dim conventionFI As Variant: Set conventionFI = host.InvokeMethod(conventionBuilderFI, "build")
    
                Dim templateFI As Variant: Set templateFI = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.FixedIborSwapTemplate", "of", startPeriod, tenor, conventionFI)
                Set trade = host.InvokeMethod(templateFI, "createTrade", tradeDate, directionFI, notional, rateFI, dd.ReferenceData)
                
            Case "FIXED / OVERNIGHT", "OVERNIGHT / FIXED"
            
                Dim directionFO As Variant
                Dim ccyFixedFO As Variant
                Dim frequencyFixedFO As Variant
                Dim dccFixedFO As Variant
                Dim rateFO As Double
                Dim indexFloatingFO As Variant
                Dim frequencyFloatingFO As Variant
                Dim accrualFloatingFO As Variant

                If (tradeType = "FIXED / OVERNIGHT") Then
                    Set directionFO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "BUY")
                    Set ccyFixedFO = dd.GetCurrency("G" & iText)
                    Set frequencyFixedFO = dd.GetFrequency("H" & iText)
                    Set dccFixedFO = dd.GetDaysCountConvention("I" & iText)
                    Set indexFloatingFO = dd.GetOvernightIndex("L" & iText)
                    Set frequencyFloatingFO = dd.GetFrequency("M" & iText)
                    Set accrualFloatingFO = dd.GetOvernightAccrualMethod("N" & iText)
                    rateFO = dd.GetRate("J" & iText)
                Else
                    Set directionFO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "SELL")
                    Set ccyFixedFO = dd.GetCurrency("L" & iText)
                    Set frequencyFixedFO = dd.GetFrequency("M" & iText)
                    Set dccFixedFO = dd.GetDaysCountConvention("N" & iText)
                    Set indexFloatingFO = dd.GetOvernightIndex("G" & iText)
                    Set frequencyFloatingFO = dd.GetFrequency("H" & iText)
                    Set accrualFloatingFO = dd.GetOvernightAccrualMethod("I" & iText)
                    rateFO = dd.GetRate("O" & iText)
                End If
                
                Dim ccyFloatingFO As Variant: Set ccyFloatingFO = host.InvokeMethod(indexFloatingFO, "getCurrency")
                
                If (ccyFixedFO <> ccyFloatingFO) Then
                    Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " must have the two legs defined on the same currency.")
                End If
                
                Set ccy = ccyFixedFO

                Dim conventionBuilderFixedFO As Variant: Set conventionBuilderFixedFO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.FixedRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFixedFO, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderFixedFO, "accrualFrequency", frequencyFixedFO)
                Call host.InvokeMethod(conventionBuilderFixedFO, "currency", ccyFixedFO)
                Call host.InvokeMethod(conventionBuilderFixedFO, "dayCount", dccFixedFO)
                Call host.InvokeMethod(conventionBuilderFixedFO, "paymentDateOffset", da)
                Dim conventionFixedFO As Variant: Set conventionFixedFO = host.InvokeMethod(conventionBuilderFixedFO, "build")
                
                Dim conventionBuilderFloatingFO As Variant: Set conventionBuilderFloatingFO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.OvernightRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFloatingFO, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderFloatingFO, "index", indexFloatingFO)
                Call host.InvokeMethod(conventionBuilderFloatingFO, "paymentDateOffset", da)
                Dim conventionFloatingFO As Variant: Set conventionFloatingFO = host.InvokeMethod(conventionBuilderFloatingFO, "build")

                Dim conventionBuilderFO As Variant: Set conventionBuilderFO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.ImmutableFixedOvernightSwapConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFO, "fixedLeg", conventionFixedFO)
                Call host.InvokeMethod(conventionBuilderFO, "floatingLeg", conventionFloatingFO)
                Call host.InvokeMethod(conventionBuilderFO, "name", "CONVENTION-INTERESTRATESWAP-" & CStr(i - 2))
                Call host.InvokeMethod(conventionBuilderFO, "spotDateOffset", da)
                Dim conventionFO As Variant: Set conventionFO = host.InvokeMethod(conventionBuilderFO, "build")
    
                Dim templateFO As Variant: Set templateFO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.FixedOvernightSwapTemplate", "of", startPeriod, tenor, conventionFO)
                Set trade = host.InvokeMethod(templateFO, "createTrade", tradeDate, directionFO, notional, rateFO, dd.ReferenceData)

            Case "IBOR / OVERNIGHT", "OVERNIGHT / IBOR"
                     
                Dim directionIO As Variant
                Dim indexIborIO As Variant
                Dim indexOvernightIO As Variant
                Dim frequencyOvernightIO As Variant
                Dim accrualOvernightIO As Variant
                Dim spreadIO As Double
            
                If (tradeType = "IBOR / OVERNIGHT") Then
                    Set directionIO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "SELL")
                    Set indexIborIO = dd.GetIborIndex("G" & iText)
                    Set indexOvernightIO = dd.GetOvernightIndex("L" & iText)
                    Set frequencyOvernightIO = dd.GetFrequency("M" & iText)
                    Set accrualOvernightIO = dd.GetOvernightAccrualMethod("N" & iText)
                    spreadIO = dd.GetRate("O" & iText)
                Else
                    Set directionIO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "BUY")
                    Set indexIborIO = dd.GetIborIndex("L" & iText)
                    Set indexOvernightIO = dd.GetOvernightIndex("G" & iText)
                    Set frequencyOvernightIO = dd.GetFrequency("H" & iText)
                    Set accrualOvernightIO = dd.GetOvernightAccrualMethod("I" & iText)
                    spreadIO = dd.GetRate("J" & iText)
                End If
                
                Dim ccyIborIO As Variant: Set ccyIborIO = host.InvokeMethod(indexIborIO, "getCurrency")
                Dim ccyOvernightIO As Variant: Set ccyOvernightIO = host.InvokeMethod(indexOvernightIO, "getCurrency")
                
                If (ccyIborIO <> ccyOvernightIO) Then
                    Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " must have the two legs defined on the same currency.")
                End If
                
                Set ccy = ccyIborIO
                
                Dim conventionBuilderIborIO As Variant: Set conventionBuilderIborIO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderIborIO, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderIborIO, "index", indexIborIO)
                Call host.InvokeMethod(conventionBuilderIborIO, "notionalExchange", False)
                Call host.InvokeMethod(conventionBuilderIborIO, "paymentDateOffset", da)
                Dim conventionIborIO As Variant: Set conventionIborIO = host.InvokeMethod(conventionBuilderIborIO, "build")
                
                Dim conventionBuilderOvernightIO As Variant: Set conventionBuilderOvernightIO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.OvernightRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderOvernightIO, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderOvernightIO, "index", indexOvernightIO)
                Call host.InvokeMethod(conventionBuilderOvernightIO, "paymentDateOffset", da)
                Dim conventionOvernightIO As Variant: Set conventionOvernightIO = host.InvokeMethod(conventionBuilderOvernightIO, "build")

                Dim conventionBuilderIO As Variant: Set conventionBuilderIO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.ImmutableOvernightIborSwapConvention", "builder")
                Call host.InvokeMethod(conventionBuilderIO, "iborLeg", conventionIborIO)
                Call host.InvokeMethod(conventionBuilderIO, "overnightLeg", conventionOvernightIO)
                Call host.InvokeMethod(conventionBuilderIO, "name", "CONVENTION-INTERESTRATESWAP-" & CStr(i - 2))
                Call host.InvokeMethod(conventionBuilderIO, "spotDateOffset", da)
                Dim conventionIO As Variant: Set conventionIO = host.InvokeMethod(conventionBuilderIO, "build")
    
                Dim templateIO As Variant: Set templateIO = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.OvernightIborSwapTemplate", "of", startPeriod, tenor, conventionIO)
                Set trade = host.InvokeMethod(templateIO, "createTrade", tradeDate, directionIO, notional, spreadIO, dd.ReferenceData)

            Case "IBOR FLAT / IBOR SPREAD", "IBOR SPREAD / IBOR FLAT"
            
                Dim directionFS As Variant
                Dim indexIborFlatFS As Variant
                Dim indexIborSpreadFS As Variant
                Dim spreadFS As Double
            
                If (tradeType = "IBOR FLAT / IBOR SPREAD") Then
                    Set directionFS = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "SELL")
                    Set indexIborFlatFS = dd.GetIborIndex("G" & iText)
                    Set indexIborSpreadFS = dd.GetIborIndex("L" & iText)
                    spreadFS = dd.GetRate("M" & iText)
                Else
                    Set directionFS = host.InvokeMethodStaticFromName("com.opengamma.strata.product.common.BuySell", "of", "BUY")
                    Set indexIborFlatFS = dd.GetIborIndex("L" & iText)
                    Set indexIborSpreadFS = dd.GetIborIndex("G" & iText)
                    spreadFS = dd.GetRate("H" & iText)
                End If
                
                Dim ccyIborFlatFS As Variant: Set ccyIborFlatFS = host.InvokeMethod(indexIborFlatFS, "getCurrency")
                Dim ccyIborSpreadFS As Variant: Set ccyIborSpreadFS = host.InvokeMethod(indexIborSpreadFS, "getCurrency")
                
                If (ccyIborFlatFS <> ccyIborSpreadFS) Then
                    Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " must have the two legs defined on the same currency.")
                End If
                
                Set ccy = ccyIborFlatFS
                
                Dim tenorIborFlatFS As Variant: Set tenorIborFlatFS = host.InvokeMethod(indexIborFlatFS, "getTenor")
                Dim tenorIborSpreadFS As Variant: Set tenorIborSpreadFS = host.InvokeMethod(indexIborSpreadFS, "getTenor")
                Dim tenorComparison As Long: tenorComparison = host.InvokeMethod(tenorIborFlatFS, "compareTo", tenorIborSpreadFS)
                
                If (tenorComparison <= 0) Then
                    Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " must have the tenor of the spread leg less than the tenor of the flat leg.")
                End If
                
                Dim conventionBuilderIborFlatFS As Variant: Set conventionBuilderIborFlatFS = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderIborFlatFS, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderIborFlatFS, "index", indexIborFlatFS)
                Call host.InvokeMethod(conventionBuilderIborFlatFS, "notionalExchange", False)
                Call host.InvokeMethod(conventionBuilderIborFlatFS, "paymentDateOffset", da)
                Dim conventionIborFlatFS As Variant: Set conventionIborFlatFS = host.InvokeMethod(conventionBuilderIborFlatFS, "build")

                Dim conventionBuilderIborSpreadFS As Variant: Set conventionBuilderIborSpreadFS = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborRateSwapLegConvention", "builder")
                Call host.InvokeMethod(conventionBuilderIborSpreadFS, "accrualBusinessDayAdjustment", bda)
                Call host.InvokeMethod(conventionBuilderIborSpreadFS, "index", indexIborSpreadFS)
                Call host.InvokeMethod(conventionBuilderIborSpreadFS, "notionalExchange", False)
                Call host.InvokeMethod(conventionBuilderIborSpreadFS, "paymentDateOffset", da)
                Dim conventionIborSpreadFS As Variant: Set conventionIborSpreadFS = host.InvokeMethod(conventionBuilderIborSpreadFS, "build")
                
                Dim conventionBuilderFS As Variant: Set conventionBuilderFS = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.ImmutableIborIborSwapConvention", "builder")
                Call host.InvokeMethod(conventionBuilderFS, "flatLeg", conventionIborFlatFS)
                Call host.InvokeMethod(conventionBuilderFS, "spreadLeg", conventionIborSpreadFS)
                Call host.InvokeMethod(conventionBuilderFS, "name", "CONVENTION-INTERESTRATESWAP-" & CStr(i - 2))
                Call host.InvokeMethod(conventionBuilderFS, "spotDateOffset", da)
                Dim conventionFS As Variant: Set conventionFS = host.InvokeMethod(conventionBuilderFS, "build")
    
                Dim templateFS As Variant: Set templateFS = host.InvokeMethodStaticFromName("com.opengamma.strata.product.swap.type.IborIborSwapTemplate", "of", startPeriod, tenor, conventionFS)
                Set trade = host.InvokeMethod(templateFS, "createTrade", tradeDate, directionFS, notional, spreadFS, dd.ReferenceData)

            Case Else
                Call Err.Raise(vbObjectError + 1, "Pricing.PricingInterestRateSwap", "The trade " & CStr(i - 2) & " is defined on an invalid convention.")
        
        End Select

        Dim tradeInfo As Variant: Set tradeInfo = dd.CreateTradeInfo(i - 2, tradeDate)
        Set trade = host.InvokeMethod(trade, "withInfo", tradeInfo)
        Set trade = host.InvokeMethod(trade, "resolve", dd.ReferenceData)

        Dim pv As Variant: Set pv = host.InvokeMethod(pricer, "presentValue", trade, dd.RatesProvider)
        Dim pvAmount As Variant: Set pvAmount = host.InvokeMethod(pv, "getAmountOrZero", ccy)
        Dim pvValue As Double: pvValue = host.InvokeMethod(pvAmount, "getAmount")

        Dim pv01Value As Double
        
        If (pvValue = 0) Then
            pv01Value = 0
        Else
            Dim pv01 As Variant: Set pv01 = host.InvokeMethod(pricer, "pv01CalibratedSum", trade, dd.RatesProvider)
            Dim pv01Amount As Variant: Set pv01Amount = host.InvokeMethod(pv01, "getAmountOrZero", ccy)
            pv01Value = host.InvokeMethod(pv01Amount, "getAmount")
        End If

        ws.Cells(i, cc - 1).Value = pvValue
        ws.Cells(i, cc).Value = pv01Value

        With Application.Union(wsCashFlows.Cells(2, cashFlowsOffset), wsCashFlows.Cells(2, cashFlowsOffset + 1), wsCashFlows.Cells(2, cashFlowsOffset + 2))
            .Merge
            .Value2 = "Trade " & CStr(i - 2)
            .Borders.Color = 0
            .Borders.LineStyle = xlContinuous
            .Borders.Weight = xlThin
            .Font.Bold = True
            .Font.Size = 13
            .Interior.Color = 11573124
        End With
        
        wsCashFlows.Columns(cashFlowsOffset).ColumnWidth = 11
        wsCashFlows.Columns(cashFlowsOffset + 1).ColumnWidth = 5
        wsCashFlows.Columns(cashFlowsOffset + 2).ColumnWidth = 14
        
        If (pvValue <> 0) Then
        
            Dim cashFlows As Variant: Set cashFlows = host.InvokeMethod(pricer, "cashFlows", trade, dd.RatesProvider)
            Dim cashFlowsSorted As Variant: Set cashFlowsSorted = host.InvokeMethod(cashFlows, "sorted")
            Dim cashFlowsSortedList As Variant: Set cashFlowsSortedList = host.InvokeMethod(cashFlowsSorted, "getCashFlows")
            Dim cashFlowsSortedListCount As Long: cashFlowsSortedListCount = host.InvokeMethod(cashFlowsSortedList, "size")
            
            For j = 0 To cashFlowsSortedListCount - 1
            
                Dim cashFlow As Variant: Set cashFlow = host.InvokeMethod(cashFlowsSortedList, "get", j)
                Dim cashFlowAmount As Variant: Set cashFlowAmount = host.InvokeMethod(cashFlow, "getPresentValue")
                Dim cashFlowPaymentDate As Variant: Set cashFlowPaymentDate = host.InvokeMethod(cashFlow, "getPaymentDate")

                With wsCashFlows.Cells(j + 3, cashFlowsOffset)
                    .Value2 = host.InvokeMethod(cashFlowPaymentDate, "format", dd.ReferenceDateFormatter)
                    .NumberFormat = "dd/mm/yyyy"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 1)
                    .Value2 = CStr(ccy)
                    .NumberFormat = "@"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
                
                With wsCashFlows.Cells(j + 3, cashFlowsOffset + 2)
                    .Value2 = host.InvokeMethod(cashFlowAmount, "getAmount")
                    .NumberFormat = "#,##0.00"
                    .Borders.Color = 0
                    .Borders.LineStyle = xlContinuous
                    .Borders.Weight = xlThin
                    .Interior.Color = 16777215
                End With
            
            Next j

        End If
        
        cashFlowsOffset = cashFlowsOffset + 3

    Next i
    
    With wsCashFlows.UsedRange.Rows(0)
        .Merge
        .Value2 = "INTEREST RATE SWAP TRADES"
        .Borders.Color = 0
        .Borders.LineStyle = xlContinuous
        .Borders.Weight = xlThin
        .Font.Bold = True
        .Font.Size = 13
        .Interior.Color = 11573124
    End With
    
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    
    Exit Sub
    
ErrorHandler:

    Application.ScreenUpdating = True
    Application.EnableEvents = True

    Call Err.Raise(Err.Number, Err.Source, Err.Description, Err.HelpFile, Err.HelpContext)

End Sub

