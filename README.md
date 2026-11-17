
https://john.toebes.com/projects/electronics#mce_temp_url#

### Gnome Sort - The Simplest Sort Algorithm  
The simplest sort algorithm is not Bubble Sort..., it is not Insertion Sort..., it's **Gnome Sort!**  

Gnome Sort is based on the technique used by the standard Dutch Garden Gnome (Du.: tuinkabouter). Here is how a garden gnome sorts a line of flower pots. Basically, he looks at the flower pot next to him and the previous one; if they are in the right order he steps one pot forward, otherwise he swaps them and steps one pot backwards. Boundary conditions: if there is no previous pot, he steps forwards; if there is no pot next to him, he is done.
```
void gnomesort(int n, int ar[]) {  
	int i = 0;  
	
	while (i < n) {  
		if (i == 0 || ar[i-1] <= ar[i]) i++;  
		else {int tmp = ar[i]; ar[i] = ar[i-1]; ar[--i] = tmp;}  
	}  
}  
```
```
function gnomeSort(a[0..size-1]) {
   i := 1
   j := 2
   while i < size {
      if a[i-1] >= a[i] {
         i := j
         j := j + 1
      } else {
         swap a[i-1] and a[i]
         i := i - 1
         if i = 0 {
            i := 1
         }
      }
   }
}
```
```
;
; PARAMETERS
;    SORT_ARRAY - Array to be sorted
;    SORT_LENGTH - Number of bytes in the array to sort
;    SORT_J - Temporary variable to hold the end sort pointer
;
;    NOTES on implementation
;    This uses the typical XOR trick to swap the two array elements
;    FSR points to the second of the two array elements that we are comparing.
;    
SORT
        MOVLW    SORT_ARRAY+1
        MOVWF    FSR        ;  i = 1
        INCF     FSR,W
        MOVWF    SORT_J     ;  j := 2
SORT_1                      ;  while i < size
        MOVFW    INDF       ;  a[i]
        DECF     FSR
        SUBWF    INDF,W
        SKPNC
        GOTO     SORT_2
                            ;    if a[i-1] >= a[i]
        MOVFW    SORT_J     ;        i := j
        MOVWF    FSR
        SUBLW    SORT_ARRAY+SORT_LENGTH-1
        SKPC
        RETURN
        INCF     SORT_J,F   ;        j := j + 1 
        GOTO     SORT_1
SORT_2                      ;    else
        SUBWF    INDF,W     ; Recover a[i]
        XORWF    INDF,W     ; Swap a[i] and value for a[i-1]
        XORWF    INDF,F
        XORWF    INDF,W
        INCF     FSR        ; point to a[i]
        MOVWF    INDF       ; store a[i]
        DECF     FSR        ;        i := i - 1
        MOVLW    SORT_ARRAY
        SUBWF    FSR,W      ;        if i = 0
        SKPNZ
        INCF     FSR,F      ;          i := 1
        GOTO     SORT_1     ; }    
        END
 ```
