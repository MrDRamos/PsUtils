# Let's make complex numbers using .NET
[Reflection.Assembly]::LoadWithPartialName("System.Numerics") | Out-Null

# Create complex numbers
$complex1 = [System.Numerics.Complex]::new(3, 4) # 3 + 4i
$complex2 = [System.Numerics.Complex]::new(1, 2) # 1 + 2i

# Add two complex numbers
$sum = [System.Numerics.Complex]::Add($complex1, $complex2) # 4 + 6i

# Multiply two complex numbers
$product = [System.Numerics.Complex]::Multiply($complex1, $complex2) # -5 + 10i

# Display the results
"Sum: $sum"
"Product: $product"
