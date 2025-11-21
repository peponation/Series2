package com.example;

public class CloneTest {

    // Original method (Target of duplication)
    public int calculateArea(int width, int height) {
        // Clone Type I - whitespace/comment changes
        if (width <= 0 || height <= 0) { // Check for validity
            return 0;
        }

        int area = width * height;

        return area;
    }

    // Clone Type I (Exact clone with minimal change)
    public int calculateVolume(int width, int height, int depth) {
        if (width <= 0 || height <= 0) {
            return 0;
        }
        
        // This 'if' block is identical to the one in calculateArea (Type I clone)
        if (depth <= 0) { 
            return 0;
        }

        int volume = width * height * depth;

        return volume;
    }
    
    // Clone Type II (Parameterized clone)
    public int computePerimeter(int lengthA, int lengthB) {
        // Clone Type II - Identifier Renaming (lengthA/lengthB vs width/height)
        if (lengthA <= 0 || lengthB <= 0) {
            return 0;
        }

        int perimeter = 2 * (lengthA + lengthB);

        return perimeter;
    }

    // Clone Type III (Near-miss clone)
    public int analyzeData(int count, int data) {
        // Clone Type III - Statement Added (Type I portion starts below)
        System.out.println("Starting analysis..."); // Added statement

        if (count <= 0 || data <= 0) {
            return -1; // Changed literal/return value
        }

        int result = count * data;
        
        // Minor modification to the original logic
        if (result > 100) {
            result = result / 2;
        }

        return result;
    }
}