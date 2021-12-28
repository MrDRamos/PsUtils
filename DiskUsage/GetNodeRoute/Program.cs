using System;
using System.Collections.Generic;
using System.Diagnostics;


namespace GetNodeRoute
{
  class Program
  {

    public static (int, string[]) GetNodeRoute(string from, string dest, int offset = 0)
    {
      int matchPos = 0;
      int maxPos = Math.Min(from.Length, dest.Length);
      int i = offset;
      for (; i < maxPos; i++)
      {
        if (from[i] != dest[i])
        {
          break;
        }
        if (from[i] == System.IO.Path.DirectorySeparatorChar)
        {
          matchPos = i +1;
        }
      }
      if (i == maxPos)
      {
        matchPos = maxPos +1;
      }

      int popCount = 0;
      if (matchPos < from.Length)
      {
        for (i = matchPos; i < from.Length; i++)
        {
          if (from[i] == System.IO.Path.DirectorySeparatorChar)
          {
            popCount++;
          }
        }
        popCount++;
      }

      List<string> pushDirS = new List<string>();
      if (matchPos < dest.Length)
      {
        for (i = matchPos; i < dest.Length; i++)
        {
          if (dest[i] == System.IO.Path.DirectorySeparatorChar)
          {
            pushDirS.Add(dest.Substring(matchPos, i - matchPos));
            matchPos = i +1;
          }
        }
        pushDirS.Add(dest.Substring(matchPos, i - matchPos));
      }

      return (popCount, pushDirS.ToArray());
    }


    static void Main(string[] args)
    {
      Console.WriteLine("Hello World!");

      string baseDir = $"C:\\users\\{Environment.UserName}";
      string fromDir = $"{baseDir}\\Documents\\WindowsPowerShell";
      string destDir = $"{baseDir}\\appdata\\local\\temp\\MyTempApp\\logs";

      int       popCount;
      string[]  pushDirS;

      for (int i = 0; i < 100; i++)
      {
        (popCount, pushDirS) = GetNodeRoute(fromDir, destDir);
        (popCount, pushDirS) = GetNodeRoute(destDir, fromDir);
      }

      Stopwatch stopWatch = new Stopwatch();
      stopWatch.Start();

      for (int i = 0; i < 100000; i++)
      {
        (popCount, pushDirS) = GetNodeRoute(baseDir, baseDir);

        (popCount, pushDirS) = GetNodeRoute(baseDir, fromDir);
        (popCount, pushDirS) = GetNodeRoute(fromDir, baseDir);

        (popCount, pushDirS) = GetNodeRoute(fromDir, destDir, baseDir.Length);
        (popCount, pushDirS) = GetNodeRoute(destDir, fromDir, baseDir.Length);

        //(popCount, pushDirS) = GetNodeRoute(fromDir, destDir);
        //(popCount, pushDirS) = GetNodeRoute(destDir, fromDir);
      }

      stopWatch.Stop();
      Console.WriteLine($"Time(ms): {stopWatch.ElapsedMilliseconds}");

    }
  }
}
