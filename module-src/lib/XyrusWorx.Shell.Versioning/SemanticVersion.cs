using System;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using JetBrains.Annotations;

namespace XyrusWorx
{
	[PublicAPI]
	public struct SemanticVersion : IComparable<SemanticVersion>, IEquatable<SemanticVersion>
	{
		private readonly string[] mPreRelease;
		private readonly string[] mMetadata;

		public SemanticVersion(int major, int minor) 
			: this(major, minor, 0, string.Empty) { }
		
		public SemanticVersion(int major, int minor, int patch) 
			: this(major, minor, patch, string.Empty) { }
		
		public SemanticVersion(int major, int minor, int patch, string preReleaseIdentifier, params string[] buildMetadata) 
			: this(major, minor, patch, new[] { preReleaseIdentifier }.Where(x => !string.IsNullOrEmpty(x)).ToArray(), buildMetadata) { }
		
		public SemanticVersion(int major, int minor, int patch, string[] preReleaseIdentifiers, string[] buildMetadata)
		{
			if (major < 0)
			{
				throw new ArgumentOutOfRangeException(nameof(major));
			}
			if (minor < 0)
			{
				throw new ArgumentOutOfRangeException(nameof(minor));
			}
			if (patch < 0)
			{
				throw new ArgumentOutOfRangeException(nameof(patch));
			}

			Major = major;
			Minor = minor;
			PatchNumber = patch;

			var strictAlphanumeric = new Regex("^[0-9A-Za-z-]+$");

			if (preReleaseIdentifiers != null && preReleaseIdentifiers.Any(x => !strictAlphanumeric.IsMatch(x)))
			{
				throw new ArgumentException($"The pre-release identifier is invalid: {string.Join(".", preReleaseIdentifiers)}");
			}

			if (buildMetadata != null && buildMetadata.Any(x => !strictAlphanumeric.IsMatch(x)))
			{
				throw new ArgumentException($"The build metadata is invalid: {string.Join(".", buildMetadata)}");
			}

			mPreRelease = preReleaseIdentifiers ?? new string[0];
			mMetadata = buildMetadata ?? new string[0];
		}

		public int Major { get; }
		public int Minor { get; }
		public int PatchNumber { get; }

		public bool IsEmpty
		{
			get => Major == 0 && Minor == 0 && PatchNumber == 0 && (mPreRelease == null || mPreRelease.Length == 0) && (mMetadata == null || mMetadata.Length == 0);
		}

		[NotNull]
		public string[] PreReleaseIdentifiers
		{
			get => mPreRelease ?? new string[0];
		}

		public string PreReleaseString
		{
			get => string.Join(".", PreReleaseIdentifiers).NormalizeNull();
		}

		[NotNull]
		public string[] BuildMetadata
		{
			get => mMetadata ?? new string[0];
		}

		public string BuildMetadataString
		{
			get => string.Join(".", BuildMetadata).NormalizeNull();
		}

		[Pure]
		public SemanticVersion RaiseMajor() => new SemanticVersion(Major + 1, 0, 0, new string[0], BuildMetadata);

		[Pure]
		public SemanticVersion RaiseMinor() => new SemanticVersion(Major, Minor + 1, 0, new string[0], BuildMetadata);

		[Pure]
		public SemanticVersion Patch() => new SemanticVersion(Major, Minor, PatchNumber + 1, new string[0], BuildMetadata);

		[Pure]
		public SemanticVersion WithMetadata([NotNull] string[] buildMetadata)
		{
			if (buildMetadata == null || buildMetadata.Length == 0)
			{
				throw new ArgumentNullException(nameof(buildMetadata));
			}

			return new SemanticVersion(Major, Minor, PatchNumber, PreReleaseIdentifiers, buildMetadata);
		}

		[Pure]
		public SemanticVersion WithMetadata([NotNull] string buildMetadata, params string[] additionalBuildMetadata)
		{
			if (buildMetadata.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(buildMetadata));
			}

			return new SemanticVersion(Major, Minor, PatchNumber, PreReleaseIdentifiers, new[] { buildMetadata }.Concat(additionalBuildMetadata).ToArray());
		}

		[Pure]
		public SemanticVersion DeclarePreRelease([NotNull] string[] preReleaseIdentifiers)
		{
			if (preReleaseIdentifiers == null || preReleaseIdentifiers.Length == 0)
			{
				throw new ArgumentNullException(nameof(preReleaseIdentifiers));
			}

			return new SemanticVersion(Major, Minor, PatchNumber, preReleaseIdentifiers, BuildMetadata);
		}

		[Pure]
		public SemanticVersion DeclarePreRelease([NotNull] string prePreleaseIdentifier, params string[] otherPreReleaseIdentifiers)
		{
			if (prePreleaseIdentifier.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(prePreleaseIdentifier));
			}

			return new SemanticVersion(Major, Minor, PatchNumber, new []{prePreleaseIdentifier}.Concat(otherPreReleaseIdentifiers).ToArray(), BuildMetadata);
		}

		[Pure]
		public SemanticVersion WithoutMetadata() => new SemanticVersion(Major, Minor, PatchNumber, PreReleaseIdentifiers, new string[0]);

		[Pure]
		public SemanticVersion DeclareFinal() => new SemanticVersion(Major, Minor, PatchNumber, new string[0], BuildMetadata);

		[Pure]
		public SemanticVersionRange CompatibleRange()
		{
			if (IsEmpty)
			{
				return SemanticVersionRange.Any();
			}

			var min = new SemanticVersion(Major, Minor, 0, mPreRelease, new string[0]);
			var max = new SemanticVersion(Major + 1, 0);

			return SemanticVersionRange.BetweenIncludingMinimumWithoutMaximum(min, max);
		}

		public override bool Equals(object obj)
		{
			if (ReferenceEquals(null, obj))
			{
				return false;
			}
			return obj is SemanticVersion version && Equals(version);
		}
		public override int GetHashCode()
		{
			unchecked
			{
				if (IsEmpty)
				{
					return 0;
				}

				var pre = PreReleaseIdentifiers.Any() ? new StringKeySequence(PreReleaseIdentifiers) : new StringKeySequence();
				var hashCode = 17;

				hashCode = (hashCode * 397) ^ Major;
				hashCode = (hashCode * 397) ^ Minor;
				hashCode = (hashCode * 397) ^ PatchNumber;
				hashCode = (hashCode * 397) ^ pre.GetHashCode();

				return hashCode;
			}
		}
		public override string ToString() => ToString(true);

		public static bool operator ==(SemanticVersion left, SemanticVersion right) => left.Equals(right);
		public static bool operator !=(SemanticVersion left, SemanticVersion right) => !left.Equals(right);
		public static bool operator <(SemanticVersion left, SemanticVersion right) => left.CompareTo(right) > 0;
		public static bool operator >(SemanticVersion left, SemanticVersion right) => left.CompareTo(right) < 0;

		[Pure]
		public int CompareTo(SemanticVersion other)
		{
			const int larger = 1;
			const int smaller = -1;
			const int equal = 0;

			if (IsEmpty && other.IsEmpty)
			{
				return equal;
			}
			if (IsEmpty && !other.IsEmpty)
			{
				return smaller;
			}
			if (!IsEmpty && other.IsEmpty)
			{
				return larger;
			}

			if (Major > other.Major)
			{
				return larger;
			}
			if (Major < other.Major)
			{
				return smaller;
			}

			if (Minor > other.Minor)
			{
				return larger;
			}
			if (Minor < other.Minor)
			{
				return smaller;
			}

			if (PatchNumber > other.PatchNumber)
			{
				return larger;
			}
			if (PatchNumber < other.PatchNumber)
			{
				return smaller;
			}

			if (!PreReleaseIdentifiers.Any() && other.PreReleaseIdentifiers.Any())
			{
				return larger;
			}
			if (PreReleaseIdentifiers.Any() && !other.PreReleaseIdentifiers.Any())
			{
				return smaller;
			}

			if (PreReleaseIdentifiers.Length > other.PreReleaseIdentifiers.Length)
			{
				return larger;
			}
			if (PreReleaseIdentifiers.Length < other.PreReleaseIdentifiers.Length)
			{
				return smaller;
			}

			var num = new Regex("^[0-9]+$", RegexOptions.Compiled);

			for (var i = 0; i < PreReleaseIdentifiers.Length; i++)
			{
				var pThis = PreReleaseIdentifiers[i];
				var pOther = other.PreReleaseIdentifiers[i];

				if (num.IsMatch(pThis) && !num.IsMatch(pOther))
				{
					return smaller;
				}
				if (!num.IsMatch(pThis) && num.IsMatch(pOther))
				{
					return larger;
				}

				if (num.IsMatch(pThis) && num.IsMatch(pOther))
				{
					var iThis = int.Parse(pThis);
					var iOther = int.Parse(pOther);

					if (iThis == iOther)
					{
						continue;
					}

					return iThis.CompareTo(iOther);
				}

				if (string.Equals(pThis, pOther, StringComparison.Ordinal))
				{
					continue;
				}

				return string.Compare(pThis, pOther, StringComparison.Ordinal);
			}

			return equal;
		}

		[Pure]
		public bool Equals(SemanticVersion other)
		{
			if (IsEmpty && other.IsEmpty)
			{
				return true;
			}

			if (IsEmpty != other.IsEmpty)
			{
				return false;
			}

			var preA = PreReleaseIdentifiers.Any() ? new StringKeySequence(PreReleaseIdentifiers) : new StringKeySequence();
			var preB = other.PreReleaseIdentifiers.Any() ? new StringKeySequence(other.PreReleaseIdentifiers) : new StringKeySequence();

			return
				Major == other.Major &&
				Minor == other.Minor &&
				PatchNumber == other.PatchNumber &&
				preA.Equals(preB);
		}

		[Pure]
		public string ToString(bool includeMetadata)
		{
			if (IsEmpty)
			{
				return "0.0.0";
			}

			var sb = new StringBuilder();

			sb.AppendFormat("{0}.{1}.{2}", Major, Minor, PatchNumber);

			for (var iPre = 0; iPre < PreReleaseIdentifiers.Length; iPre++)
			{
				sb.AppendFormat("{1}{0}", PreReleaseIdentifiers[iPre], iPre == 0 ? '-' : '.');
			}

			if (includeMetadata)
			{
				for (var iMeta = 0; iMeta < BuildMetadata.Length; iMeta++)
				{
					sb.AppendFormat("{1}{0}", BuildMetadata[iMeta], iMeta == 0 ? '+' : '.');
				}
			}

			return sb.ToString();
		}

		public static SemanticVersion Empty
		{
			get => new SemanticVersion();
		}

		public static SemanticVersion Parse(string versionString)
		{
			if (!TryParse(versionString, out var version))
			{
				throw new FormatException();
			}

			return version;
		}

		public static bool TryParse(string versionString, out SemanticVersion version)
		{
			var regex = new Regex(@"^(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:-([\da-z\-]+(?:\.[\da-z\-]+)*))?(?:\+([\da-z\-]+(?:\.[\da-z\-]+)*))?$", RegexOptions.IgnoreCase);
			var match = regex.Match(versionString ?? string.Empty);

			if (!match.Success)
			{
				version = default(SemanticVersion);
				return false;
			}

			var major = int.Parse(match.Groups[1].Value);
			var minor = int.Parse(match.Groups[2].Value);
			var patch = !string.IsNullOrEmpty(match.Groups[3].Value) ? int.Parse(match.Groups[3].Value) : 0;

			var preRelease = match.Groups[4].Value.Split(new[]{ '.' }, StringSplitOptions.RemoveEmptyEntries);
			var metadata = match.Groups[5].Value.Split(new[] { '.' }, StringSplitOptions.RemoveEmptyEntries);

			version = new SemanticVersion(major, minor, patch, preRelease, metadata);
			return true;
		}
	}
}