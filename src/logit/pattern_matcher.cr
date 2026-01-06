module Logit
  module PatternMatcher
    # Check if a namespace matches a glob pattern
    # Supports:
    # - Exact matching: "MyLib::HTTP" matches "MyLib::HTTP"
    # - Single wildcard (*): "MyLib::*" matches "MyLib::HTTP" but not "MyLib::HTTP::Client"
    # - Multi wildcard (**): "MyLib::**" matches "MyLib::HTTP" and "MyLib::HTTP::Client"
    def self.match?(namespace : String, pattern : String) : Bool
      # Normalize inputs (remove leading/trailing ::)
      ns_parts = normalize(namespace)
      pattern_parts = normalize(pattern)

      match_parts?(ns_parts, pattern_parts, 0, 0)
    end

    private def self.normalize(path : String) : Array(String)
      path.split("::").reject(&.empty?)
    end

    private def self.match_parts?(ns_parts : Array(String), pattern_parts : Array(String),
                                   ns_idx : Int32, pat_idx : Int32) : Bool
      # If we've exhausted the pattern
      if pat_idx >= pattern_parts.size
        # Match only if we've also exhausted the namespace
        return ns_idx >= ns_parts.size
      end

      # If we've exhausted the namespace but not the pattern
      if ns_idx >= ns_parts.size
        # Only match if remaining pattern is all **
        return pattern_parts[pat_idx..].all? { |p| p == "**" }
      end

      pat_part = pattern_parts[pat_idx]
      ns_part = ns_parts[ns_idx]

      case pat_part
      when "*"
        # Match single component and continue
        # First check if there are more namespace components to match
        if ns_idx + 1 > ns_parts.size
          return false
        end
        match_parts?(ns_parts, pattern_parts, ns_idx + 1, pat_idx + 1)

      when "**"
        # Try matching zero or more components
        # Check what comes after the ** to optimize matching
        if pat_idx + 1 < pattern_parts.size
          next_pat = pattern_parts[pat_idx + 1]
          # Try to find next_pat in remaining namespace
          while ns_idx < ns_parts.size
            if ns_parts[ns_idx] == next_pat
              if match_parts?(ns_parts, pattern_parts, ns_idx, pat_idx + 1)
                return true
              end
            end
            ns_idx += 1
          end
          return false
        else
          # ** is at the end, it matches everything remaining
          return true
        end

      else
        # Exact match required
        if ns_part == pat_part
          match_parts?(ns_parts, pattern_parts, ns_idx + 1, pat_idx + 1)
        else
          false
        end
      end
    end
  end
end
