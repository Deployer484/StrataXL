VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} ReferenceDataCrossCurrency 
   Caption         =   "Reference Data"
   ClientHeight    =   2775
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   3975
   OleObjectBlob   =   "ReferenceDataCrossCurrency.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "ReferenceDataCrossCurrency"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

'====================================='
' Copyright (C) 2019 Tommaso Belluzzo '
'          Part of StrataXL           '
'====================================='

' SETTINGS

Option Base 0
Option Explicit

' IMPORTS

Private Declare PtrSafe Function FindWindow Lib "User32.dll" Alias "FindWindowA" _
( _
    ByVal lpClassName As String, _
    ByVal lpWindowName As String _
) As LongPtr

#If Win64 Then
    Private Declare PtrSafe Function GetWindowLongPtr Lib "User32.dll" Alias "GetWindowLongPtrA" _
    ( _
        ByVal hWnd As LongPtr, _
        ByVal nIndex As Long _
    ) As LongPtr
#Else
    Private Declare PtrSafe Function GetWindowLongPtr Lib "User32.dll" Alias "GetWindowLongA" _
    ( _
        ByVal hWnd As LongPtr, _
        ByVal nIndex As Long _
    ) As LongPtr
#End If

#If Win64 Then
    Private Declare PtrSafe Function SetWindowLongPtr Lib "User32.dll" Alias "SetWindowLongPtrA" _
    ( _
        ByVal hWnd As LongPtr, _
        ByVal nIndex As Long, _
        ByVal dwNewLong As LongPtr _
    ) As LongPtr
#Else
    Private Declare PtrSafe Function SetWindowLongPtr Lib "User32.dll" Alias "SetWindowLongA" _
    ( _
        ByVal hWnd As LongPtr, _
        ByVal nIndex As Long, _
        ByVal dwNewLong As LongPtr _
    ) As LongPtr
#End If

' CONSTANTS

Const GWL_STYLE As Long = -16
Const WS_SYSMENU As Long = &H80000

' MEMBERS

Dim m_ReferenceBusinessDays As String
Dim m_ReferenceCurrencyBase As String
Dim m_ReferenceCurrencyCounter As String
Dim m_ReferenceDaysCount As String
Dim m_ReferenceValuationDate As Date

' PROPERTY
' Gets the reference business days convention.

Property Get ReferenceBusinessDays() As String

    ReferenceBusinessDays = m_ReferenceBusinessDays

End Property

' PROPERTY
' Gets the reference base currency.

Property Get ReferenceCurrencyBase() As String

    ReferenceCurrencyBase = m_ReferenceCurrencyBase

End Property

' PROPERTY
' Gets the reference counter currency.

Property Get ReferenceCurrencyCounter() As String

    ReferenceCurrencyCounter = m_ReferenceCurrencyCounter

End Property

' PROPERTY
' Gets the reference days count convention.

Property Get ReferenceDaysCount() As String

    ReferenceDaysCount = m_ReferenceDaysCount

End Property

' PROPERTY
' Gets the reference valuation date.

Property Get ReferenceValuationDate() As Variant

    ReferenceValuationDate = m_ReferenceValuationDate

End Property

' CONSTRUCTOR

Private Sub UserForm_Initialize()

    Dim handle As Long, lStyle As Long
    
    If (Val(Application.Version) >= 9) Then
       handle = FindWindow("ThunderDFrame", Me.Caption)
    Else
       handle = FindWindow("ThunderXFrame", Me.Caption)
    End If
    
    Dim Style As Long: Style = GetWindowLongPtr(handle, GWL_STYLE)
    Call SetWindowLongPtr(handle, GWL_STYLE, Style And Not WS_SYSMENU)

    FieldValuationDate.Text = "15/02/2019"
    
    With FieldCurrencyBase
        .AddItem "AED"
        .AddItem "ARS"
        .AddItem "AUD"
        .AddItem "BGN"
        .AddItem "BHD"
        .AddItem "BRL"
        .AddItem "CAD"
        .AddItem "CHF"
        .AddItem "CLP"
        .AddItem "CNY"
        .AddItem "CNY"
        .AddItem "COP"
        .AddItem "CZK"
        .AddItem "DKK"
        .AddItem "EGP"
        .AddItem "EUR"
        .AddItem "GBP"
        .AddItem "HKD"
        .AddItem "HRK"
        .AddItem "HUF"
        .AddItem "IDR"
        .AddItem "ILS"
        .AddItem "INR"
        .AddItem "ISK"
        .AddItem "JPY"
        .AddItem "KRW"
        .AddItem "MXN"
        .AddItem "MYR"
        .AddItem "NOK"
        .AddItem "NZD"
        .AddItem "PEN"
        .AddItem "PHP"
        .AddItem "PKR"
        .AddItem "PLN"
        .AddItem "RON"
        .AddItem "RUB"
        .AddItem "SAR"
        .AddItem "SEK"
        .AddItem "SGD"
        .AddItem "THB"
        .AddItem "TRY"
        .AddItem "TWD"
        .AddItem "UAH"
        .AddItem "USD"
        .AddItem "ZAR"
        .ListIndex = 43
    End With
    
    With FieldCurrencyCounter
        .AddItem "AED"
        .AddItem "ARS"
        .AddItem "AUD"
        .AddItem "BGN"
        .AddItem "BHD"
        .AddItem "BRL"
        .AddItem "CAD"
        .AddItem "CHF"
        .AddItem "CLP"
        .AddItem "CNY"
        .AddItem "CNY"
        .AddItem "COP"
        .AddItem "CZK"
        .AddItem "DKK"
        .AddItem "EGP"
        .AddItem "EUR"
        .AddItem "GBP"
        .AddItem "HKD"
        .AddItem "HRK"
        .AddItem "HUF"
        .AddItem "IDR"
        .AddItem "ILS"
        .AddItem "INR"
        .AddItem "ISK"
        .AddItem "JPY"
        .AddItem "KRW"
        .AddItem "MXN"
        .AddItem "MYR"
        .AddItem "NOK"
        .AddItem "NZD"
        .AddItem "PEN"
        .AddItem "PHP"
        .AddItem "PKR"
        .AddItem "PLN"
        .AddItem "RON"
        .AddItem "RUB"
        .AddItem "SAR"
        .AddItem "SEK"
        .AddItem "SGD"
        .AddItem "THB"
        .AddItem "TRY"
        .AddItem "TWD"
        .AddItem "UAH"
        .AddItem "USD"
        .AddItem "ZAR"
        .ListIndex = 15
    End With
    
    With FieldBusinessDays
        .AddItem "NO ADJUST"
        .AddItem "NEAREST"
        .AddItem "FOLLOWING"
        .AddItem "MODIFIED FOLLOWING"
        .AddItem "PRECEDING"
        .AddItem "MODIFIED PRECEDING"
        .ListIndex = 3
    End With
    
    With FieldDaysCount
        .AddItem "30/360 ISDA"
        .AddItem "30/360 PSA"
        .AddItem "30E/360"
        .AddItem "30E/360 ISDA"
        .AddItem "30E+/360"
        .AddItem "30U/360"
        .AddItem "30U/360 EOM"
        .AddItem "ACT/360"
        .AddItem "ACT/364"
        .AddItem "ACT/365.25"
        .AddItem "ACT/365A"
        .AddItem "ACT/365F"
        .AddItem "ACT/365L"
        .AddItem "ACT/ACT AFB"
        .AddItem "ACT/ACT ICMA"
        .AddItem "ACT/ACT ISDA"
        .AddItem "ACT/ACT AFB"
        .AddItem "ACT/ACT ICMA"
        .AddItem "ACT/ACT YEAR"
        .AddItem "NL/365"
        .ListIndex = 7
    End With

End Sub

' EVENT
' Raised when the OK button is clicked.

Private Sub ButtonOk_Click()

    Dim vd As String: vd = FieldValuationDate.Text
    Dim ccyBase As String: ccyBase = FieldCurrencyBase.Text
    Dim ccyCounter As String: ccyCounter = FieldCurrencyCounter.Text
    
    Dim shouldExit As Boolean: shouldExit = False
    
    If Not IsDate(vd) Then
        FieldValuationDate.BackColor = RGB(247, 215, 215)
        FieldValuationDate.BorderColor = RGB(255, 0, 0)
        shouldExit = True
    End If
    
    If (ccyBase = ccyCounter) Then
        FieldCurrencyBase.BackColor = RGB(247, 215, 215)
        FieldCurrencyBase.BorderColor = RGB(255, 0, 0)
        FieldCurrencyCounter.BackColor = RGB(247, 215, 215)
        FieldCurrencyCounter.BorderColor = RGB(255, 0, 0)
        shouldExit = True
    End If
    
    If shouldExit Then
        Exit Sub
    End If
    
    FieldValuationDate.BackColor = &H8000000F
    FieldValuationDate.BorderColor = &H80000012
    FieldCurrencyBase.BackColor = &H8000000F
    FieldCurrencyBase.BorderColor = &H80000012
    FieldCurrencyCounter.BackColor = &H8000000F
    FieldCurrencyCounter.BorderColor = &H80000012
    
    m_ReferenceBusinessDays = FieldBusinessDays.Text
    m_ReferenceCurrencyBase = FieldCurrencyBase.Text
    m_ReferenceCurrencyCounter = FieldCurrencyCounter.Text
    m_ReferenceDaysCount = FieldDaysCount.Text
    m_ReferenceValuationDate = CDate(vd)

    Me.Hide

End Sub

' EVENT
' Raised when the form is closed.

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)

    If (CloseMode = vbFormControlMenu) Then
        Cancel = True
    End If

End Sub
